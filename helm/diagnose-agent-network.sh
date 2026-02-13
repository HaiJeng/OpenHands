#!/bin/bash
# OpenHands agent-server 网络诊断脚本
# 专门诊断 agent-server 容器的端口绑定和连接问题

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="openhands-dev"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}agent-server 网络诊断${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 获取 Pod 名称
OPENHANDS_POD=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')
DIND_POD=$(kubectl get pod -n $NAMESPACE -l app=docker-dind -o jsonpath='{.items[0].metadata.name}')

echo -e "${GREEN}OpenHands Pod: $OPENHANDS_POD${NC}"
echo -e "${GREEN}DinD Pod: $DIND_POD${NC}"
echo ""

# 步骤 1: 获取 agent-server 容器信息
echo -e "${YELLOW}[1/6] 获取 agent-server 容器信息...${NC}"
AGENT_CONTAINER=$(kubectl exec -n $NAMESPACE $DIND_POD -- docker ps -a --filter "name=agent-server" --format "{{.ID}}\t{{.Names}}\t{{.Status}}" | head -1)

if [ -z "$AGENT_CONTAINER" ]; then
    echo -e "${RED}✗ 未发现 agent-server 容器${NC}"
    echo -e "${YELLOW}请通过 Web UI 创建新会话${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 发现容器:${NC}"
echo "$AGENT_CONTAINER"

CONTAINER_ID=$(echo "$AGENT_CONTAINER" | awk '{print $1}')
CONTAINER_NAME=$(echo "$AGENT_CONTAINER" | awk '{print $2}')
echo -e "${BLUE}容器 ID: $CONTAINER_ID${NC}"
echo -e "${BLUE}容器名称: $CONTAINER_NAME${NC}"
echo ""

# 步骤 2: 检查端口绑定（关键）
echo -e "${YELLOW}[2/6] 检查端口绑定（关键）...${NC}"
echo -e "${BLUE}容器端口映射:${NC}"
kubectl exec -n $NAMESPACE $DIND_POD -- docker port $CONTAINER_ID 2>/dev/null || echo -e "${RED}✗ 端口映射为空${NC}"
echo ""

echo -e "${BLUE}完整的端口配置:${NC}"
kubectl exec -n $NAMESPACE $DIND_POD -- docker ps --filter "id=$CONTAINER_ID" --format "table {{.Names}}\t{{.Ports}}"
echo ""

# 检查 33013 端口是否绑定
PORT_33013_BINDING=$(kubectl exec -n $NAMESPACE $DIND_POD -- docker port $CONTAINER_ID 33013 2>/dev/null || echo "")
if [ -z "$PORT_33013_BINDING" ]; then
    echo -e "${RED}✗ 端口 33013 未绑定到 Docker 主机${NC}"
    echo -e "${YELLOW}这是主要问题！${NC}"
    echo ""
    echo -e "${YELLOW}可能原因:${NC}"
    echo "  1. agent-server 监听在 127.0.0.1:33013（仅本地）"
    echo "  2. 应该监听 0.0.0.0:33013（所有接口）"
else
    echo -e "${GREEN}✓ 端口 33013 已绑定: $PORT_33013_BINDING${NC}"
fi
echo ""

# 步骤 3: 检查容器内部监听
echo -e "${YELLOW}[3/6] 检查容器内部监听端口...${NC}"
echo -e "${BLUE}容器内监听的端口:${NC}"

# 尝试多种方法检查监听端口
if kubectl exec -n $NAMESPACE $DIND_POD -- docker exec $CONTAINER_ID sh -c "command -v netstat" &>/dev/null; then
    kubectl exec -n $NAMESPACE $DIND_POD -- docker exec $CONTAINER_ID netstat -tuln | grep -E "Proto|33013" || echo -e "${YELLOW}未发现 33013 监听${NC}"
elif kubectl exec -n $NAMESPACE $DIND_POD -- docker exec $CONTAINER_ID sh -c "command -v ss" &>/dev/null; then
    kubectl exec -n $NAMESPACE $DIND_POD -- docker exec $CONTAINER_ID ss -tuln | grep -E "Netid|33013" || echo -e "${YELLOW}未发现 33013 监听${NC}"
else
    echo -e "${YELLOW}netstat/ss 不可用，尝试其他方法...${NC}"
    kubectl exec -n $NAMESPACE $DIND_POD -- docker exec $CONTAINER_ID cat /proc/net/tcp | head -5
fi
echo ""

# 步骤 4: 检查容器网络配置
echo -e "${YELLOW}[4/6] 检查容器网络配置...${NC}"
CONTAINER_IP=$(kubectl exec -n $NAMESPACE $DIND_POD -- docker inspect $CONTAINER_ID --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || echo "")
echo -e "${BLUE}容器 IP: $CONTAINER_IP${NC}"

NETWORK_MODE=$(kubectl exec -n $NAMESPACE $DIND_POD -- docker inspect $CONTAINER_ID --format '{{.HostConfig.NetworkMode}}' 2>/dev/null || echo "")
echo -e "${BLUE}网络模式: $NETWORK_MODE${NC}"
echo ""

# 步骤 5: 测试网络连接
echo -e "${YELLOW}[5/6] 测试网络连接...${NC}"

# 测试 1: 从 DinD Pod 内部测试
echo -e "${BLUE}测试 1: 从 DinD Pod 内连接到容器 33013${NC}"
if [ -n "$CONTAINER_IP" ]; then
    if kubectl exec -n $NAMESPACE $DIND_POD -- sh -c "nc -zv $CONTAINER_IP 33013" 2>/dev/null; then
        echo -e "${GREEN}✓ DinD Pod 可以连接到 $CONTAINER_IP:33013${NC}"
    else
        echo -e "${RED}✗ DinD Pod 无法连接到 $CONTAINER_IP:33013${NC}"
    fi
fi
echo ""

# 测试 2: 从 OpenHands Pod 测试 localhost:33013
echo -e "${BLUE}测试 2: 从 OpenHands Pod 测试 localhost:33013${NC}"
if kubectl exec -n $NAMESPACE $OPENHANDS_POD -- sh -c "nc -zv localhost 33013" 2>/dev/null; then
    echo -e "${GREEN}✓ OpenHands Pod 可以连接到 localhost:33013${NC}"
else
    echo -e "${RED}✗ OpenHands Pod 无法连接到 localhost:33013${NC}"
    echo -e "${YELLOW}这是 OpenHands 报错的原因！${NC}"
fi
echo ""

# 测试 3: 如果端口已绑定，测试绑定的端口
if [ -n "$PORT_33013_BINDING" ]; then
    HOST_PORT=$(echo "$PORT_33013_BINDING" | cut -d: -f2)
    echo -e "${BLUE}测试 3: 测试绑定的主机端口 $HOST_PORT${NC}"
    if kubectl exec -n $NAMESPACE $DIND_POD -- sh -c "nc -zv localhost $HOST_PORT" 2>/dev/null; then
        echo -e "${GREEN}✓ DinD Pod 可以连接到 localhost:$HOST_PORT${NC}"
    else
        echo -e "${RED}✗ DinD Pod 无法连接到 localhost:$HOST_PORT${NC}"
    fi
    echo ""
fi

# 步骤 6: 查看 agent-server 日志
echo -e "${YELLOW}[6/6] 查看 agent-server 日志（最后 30 行）...${NC}"
kubectl exec -n $NAMESPACE $DIND_POD -- docker logs --tail 30 $CONTAINER_ID 2>&1
echo ""

# 诊断总结
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}诊断总结${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ -z "$PORT_33013_BINDING" ]; then
    echo -e "${RED}🔴 问题确认: 端口 33013 未绑定到 Docker 主机${NC}"
    echo ""
    echo -e "${YELLOW}这意味着:${NC}"
    echo "  • agent-server 容器内部可能监听在 127.0.0.1:33013"
    echo "  • 需要改为监听 0.0.0.0:33013"
    echo "  • OpenHands 无法通过 localhost:33013 访问"
    echo ""
    echo -e "${GREEN}✅ 解决方案（按优先级）:${NC}"
    echo ""
    echo -e "${GREEN}方案 1: 重新创建会话（最简单）${NC}"
    echo "  1. 通过 Web UI 删除当前会话"
    echo "  2. 创建新会话"
    echo "  3. 重新运行此脚本验证"
    echo ""
    echo -e "${GREEN}方案 2: 重启 OpenHands Pod${NC}"
    echo "  kubectl delete pod -n $NAMESPACE $OPENHANDS_POD"
    echo "  # Pod 会自动重启并重新创建 agent-server"
    echo ""
    echo -e "${GREEN}方案 3: 检查 agent-server 启动配置${NC}"
    echo "  查看 agent-server 的配置文件和启动参数"
    echo "  确保监听 0.0.0.0 而非 127.0.0.1"
    echo ""
else
    echo -e "${GREEN}✓ 端口绑定正常${NC}"
    echo -e "${YELLOW}但 OpenHands 仍无法连接，可能原因:${NC}"
    echo "  1. OpenHands 网络配置问题"
    echo "  2. 防火墙或网络策略"
    echo "  3. agent-server 应用配置"
fi
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}下一步操作${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}推荐操作:${NC}"
echo "  1. 先尝试方案 1（重新创建会话）"
echo "  2. 如果不行，尝试方案 2（重启 Pod）"
echo "  3. 如果仍不行，查看详细日志:"
echo ""
echo -e "     kubectl logs -f -n $NAMESPACE $OPENHANDS_POD"
echo -e "     kubectl exec -n $NAMESPACE $DIND_POD -- docker logs -f $CONTAINER_ID"
echo ""
