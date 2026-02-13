#!/bin/bash
# OpenHands DinD 完整诊断和修复
# 问题: agent-server 容器不存在或无法连接

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="openhands-dev"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}OpenHands DinD 完整诊断和修复${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 获取 Pod 信息
echo -e "${YELLOW}[1/6] 检查 Pod 状态...${NC}"
OPENHANDS_POD=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
DIND_POD=$(kubectl get pod -n $NAMESPACE -l app=docker-dind -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$OPENHANDS_POD" ]; then
    echo -e "${RED}✗ OpenHands Pod 不存在${NC}"
    echo -e "${YELLOW}请先部署 OpenHands${NC}"
    exit 1
fi

if [ -z "$DIND_POD" ]; then
    echo -e "${RED}✗ DinD Pod 不存在${NC}"
    echo -e "${YELLOW}请先部署 DinD${NC}"
    exit 1
fi

echo -e "${GREEN}✓ OpenHands Pod: $OPENHANDS_POD${NC}"
echo -e "${GREEN}✓ DinD Pod: $DIND_POD${NC}"
echo ""

# 检查容器
echo -e "${YELLOW}[2/6] 检查 agent-server 容器...${NC}"
DIND_CONTAINERS=$(kubectl exec -n $NAMESPACE $DIND_POD -- docker ps -a --format "{{.Names}}" 2>/dev/null | grep -v "^docker-dind$" || echo "")

if [ -z "$DIND_CONTAINERS" ]; then
    echo -e "${RED}✗ DinD 中没有容器（除了 docker-dind 自己）${NC}"
    echo -e "${YELLOW}这意味着:${NC}"
    echo "  1. 还没有创建会话"
    echo "  2. 或者 agent-server 容器已停止"
    echo ""
    echo -e "${GREEN}解决方案:${NC}"
    echo "  1. 通过 Web UI 创建新会话（推荐）"
    echo "  2. 或重启 OpenHands Pod"
    echo ""
    
    read -p "是否重启 OpenHands Pod? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}正在重启 OpenHands Pod...${NC}"
        kubectl delete pod -n $NAMESPACE $OPENHANDS_POD
        echo -e "${GREEN}✓ Pod 已删除，正在等待重启...${NC}"
        kubectl wait --for=condition=ready pod -n $NAMESPACE -l app.kubernetes.io/name=openhands --timeout=300s
        echo -e "${GREEN}✓ Pod 已重启${NC}"
        
        # 获取新 Pod 名称
        OPENHANDS_POD=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')
        echo -e "${GREEN}新 Pod: $OPENHANDS_POD${NC}"
        echo ""
        echo -e "${YELLOW}现在请:${NC}"
        echo "  1. 访问 OpenHands Web UI"
        echo "  2. 创建新会话"
        echo "  3. 重新运行此脚本: $0"
        exit 0
    else
        echo -e "${YELLOW}请通过 Web UI 创建新会话，然后重新运行此脚本${NC}"
        exit 0
    fi
fi

echo -e "${GREEN}✓ 发现容器:${NC}"
kubectl exec -n $NAMESPACE $DIND_POD -- docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | grep -v "^NAMES"
echo ""

# 查找 agent-server 容器
AGENT_CONTAINER=$(kubectl exec -n $NAMESPACE $DIND_POD -- docker ps -a --filter "name=agent-server" --format "{{.ID}}" | head -1 2>/dev/null || echo "")

if [ -z "$AGENT_CONTAINER" ]; then
    echo -e "${RED}✗ 未发现 agent-server 容器${NC}"
    echo ""
    echo -e "${YELLOW}但这可能不是问题！${NC}"
    echo -e "${YELLOW}可能有其他会话容器正在运行${NC}"
    echo ""
    echo -e "${GREEN}建议:${NC}"
    echo "  1. 通过 Web UI 删除现有会话"
    echo "  2. 创建新会话"
    echo "  3. 重新运行此脚本"
    exit 0
fi

echo -e "${GREEN}✓ agent-server 容器 ID: $AGENT_CONTAINER${NC}"

# 获取容器详细信息
CONTAINER_IP=$(kubectl exec -n $NAMESPACE $DIND_POD -- docker inspect $AGENT_CONTAINER --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || echo "")
CONTAINER_STATUS=$(kubectl exec -n $NAMESPACE $DIND_POD -- docker inspect $AGENT_CONTAINER --format '{{.State.Status}}' 2>/dev/null || echo "")

echo -e "${GREEN}  容器 IP: $CONTAINER_IP${NC}"
echo -e "${GREEN}  容器状态: $CONTAINER_STATUS${NC}"
echo ""

# 检查容器状态
if [ "$CONTAINER_STATUS" != "running" ]; then
    echo -e "${RED}✗ 容器未运行 (状态: $CONTAINER_STATUS)${NC}"
    echo ""
    echo -e "${YELLOW}查看容器日志:${NC}"
    kubectl exec -n $NAMESPACE $DIND_POD -- docker logs --tail 30 $AGENT_CONTAINER 2>&1
    echo ""
    echo -e "${GREEN}建议:${NC}"
    echo "  1. 删除此容器并创建新会话"
    echo "  2. 或重启 OpenHands Pod"
    exit 1
fi

# 检查端口
echo -e "${YELLOW}[3/6] 检查容器端口...${NC}"
echo -e "${BLUE}容器端口映射:${NC}"
kubectl exec -n $NAMESPACE $DIND_POD -- docker port $AGENT_CONTAINER 2>/dev/null || echo -e "${YELLOW}无端口映射${NC}"
echo ""

# 检查容器内监听
echo -e "${YELLOW}[4/6] 检查容器内监听端口...${NC}"
LISTENING=$(kubectl exec -n $NAMESPACE $DIND_POD -- docker exec $AGENT_CONTAINER cat /proc/net/tcp 2>/dev/null | head -5 || echo "")
if [ -n "$LISTENING" ]; then
    echo -e "${GREEN}✓ 容器内监听的端口:${NC}"
    echo "$LISTENING"
else
    echo -e "${YELLOW}⚠ 无法查看容器内监听端口${NC}"
fi
echo ""

# 测试连接
echo -e "${YELLOW}[5/6] 测试网络连接...${NC}"

# 测试 1: 从 DinD Pod 测试容器 IP:8000
echo -e "${BLUE}测试 1: 从 DinD Pod 测试 $CONTAINER_IP:8000${NC}"
if kubectl exec -n $NAMESPACE $DIND_POD -- sh -c "timeout 3 nc -zv $CONTAINER_IP 8000" 2>/dev/null; then
    echo -e "${GREEN}✓ 可以连接到 $CONTAINER_IP:8000${NC}"
    SUCCESS_CONTAINER=true
else
    echo -e "${RED}✗ 无法连接到 $CONTAINER_IP:8000${NC}"
    SUCCESS_CONTAINER=false
fi
echo ""

# 测试 2: 从 DinD Pod 测试 localhost:33013
echo -e "${BLUE}测试 2: 从 DinD Pod 测试 localhost:33013${NC}"
if kubectl exec -n $NAMESPACE $DIND_POD -- sh -c "timeout 3 nc -zv localhost 33013" 2>/dev/null; then
    echo -e "${GREEN}✓ 可以连接到 localhost:33013${NC}"
    SUCCESS_DIND_LOCAL=true
else
    echo -e "${RED}✗ 无法连接到 localhost:33013${NC}"
    SUCCESS_DIND_LOCAL=false
fi
echo ""

# 测试 3: 从 OpenHands Pod 测试 localhost:33013
echo -e "${BLUE}测试 3: 从 OpenHands Pod 测试 localhost:33013${NC}"
if kubectl exec -n $NAMESPACE $OPENHANDS_POD -- sh -c "timeout 3 nc -zv localhost 33013" 2>/dev/null; then
    echo -e "${GREEN}✓ 可以连接到 localhost:33013${NC}"
    SUCCESS_OPENHANDS=true
else
    echo -e "${RED}✗ 无法连接到 localhost:33013${NC}"
    SUCCESS_OPENHANDS=false
fi
echo ""

# 查看 agent-server 日志
echo -e "${YELLOW}[6/6] 查看 agent-server 日志（最后 30 行）...${NC}"
kubectl exec -n $NAMESPACE $DIND_POD -- docker logs --tail 30 $AGENT_CONTAINER 2>&1
echo ""

# 诊断总结
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}诊断总结${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ "$SUCCESS_CONTAINER" = true ] && [ "$SUCCESS_DIND_LOCAL" = false ]; then
    echo -e "${RED}🔴 问题: 端口映射未正确配置${NC}"
    echo ""
    echo -e "${YELLOW}这意味着:${NC}"
    echo "  • 容器内 uvicorn 监听 8000 端口正常"
    echo "  • 但 Docker 端口映射 33013->8000 不工作"
    echo ""
    echo -e "${GREEN}✅ 推荐方案:${NC}"
    echo "  使用 socat 在 OpenHands Pod 内创建端口转发"
    echo ""
    echo "运行:"
    echo "  ./socat-fix.sh"
    echo ""
elif [ "$SUCCESS_CONTAINER" = true ] && [ "$SUCCESS_DIND_LOCAL" = true ] && [ "$SUCCESS_OPENHANDS" = false ]; then
    echo -e "${RED}🔴 问题: OpenHands Pod 无法访问 DinD${NC}"
    echo ""
    echo -e "${YELLOW}这意味着:${NC}"
    echo "  • DinD Pod 内部 localhost:33013 可访问"
    echo "  • 但 OpenHands Pod 无法访问"
    echo ""
    echo -e "${GREEN}✅ 推荐方案:${NC}"
    echo "  使用 socat 在 OpenHands Pod 内创建端口转发"
    echo ""
    echo "运行:"
    echo "  ./socat-fix.sh"
    echo ""
elif [ "$SUCCESS_CONTAINER" = false ]; then
    echo -e "${RED}🔴 问题: agent-server 容器内服务未启动${NC}"
    echo ""
    echo -e "${YELLOW}这意味着:${NC}"
    echo "  • uvicorn 未在 8000 端口监听"
    echo "  • 容器启动失败或配置错误"
    echo ""
    echo -e "${GREEN}✅ 推荐方案:${NC}"
    echo "  1. 查看容器日志（上面已显示）"
    echo "  2. 删除会话并创建新会话"
    echo "  3. 或重启 OpenHands Pod"
    echo ""
elif [ "$SUCCESS_OPENHANDS" = true ]; then
    echo -e "${GREEN}✅ 连接成功！${NC}"
    echo ""
    echo -e "${YELLOW}OpenHands Pod 可以通过 localhost:33013 访问 agent-server${NC}"
    echo ""
    echo -e "${GREEN}下一步:${NC}"
    echo "  1. 访问 OpenHands Web UI"
    echo "  2. 创建或测试会话"
    echo "  3. 应该可以正常工作"
    echo ""
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}下一步操作${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}1. 如果连接成功:${NC}"
echo "   访问 OpenHands Web UI 并测试会话"
echo ""
echo -e "${GREEN}2. 如果需要 socat 修复:${NC}"
echo "   运行: ./socat-fix.sh"
echo ""
echo -e "${GREEN}3. 如果容器未启动:${NC}"
echo "   删除会话并创建新会话"
echo ""
echo -e "${GREEN}4. 查看完整日志:${NC}"
echo "   kubectl logs -f -n $NAMESPACE $OPENHANDS_POD"
echo "   kubectl exec -n $NAMESPACE $DIND_POD -- docker logs -f $AGENT_CONTAINER"
echo ""
