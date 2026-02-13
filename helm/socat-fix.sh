#!/bin/bash
# 使用 socat 在 OpenHands Pod 内创建端口转发
# localhost:33013 -> agent-server-container:8000

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="openhands-dev"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}socat 端口转发修复${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 获取 Pod 信息
OPENHANDS_POD=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')
DIND_POD=$(kubectl get pod -n $NAMESPACE -l app=docker-dind -o jsonpath='{.items[0].metadata.name}')
AGENT_CONTAINER=$(kubectl exec -n $NAMESPACE $DIND_POD -- docker ps --filter "name=agent-server" --format "{{.ID}}" | head -1)
CONTAINER_IP=$(kubectl exec -n $NAMESPACE $DIND_POD -- docker inspect $AGENT_CONTAINER --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')

echo -e "${GREEN}OpenHands Pod: $OPENHANDS_POD${NC}"
echo -e "${GREEN}DinD Pod: $DIND_POD${NC}"
echo -e "${GREEN}Agent Container: $AGENT_CONTAINER${NC}"
echo -e "${GREEN}Container IP: $CONTAINER_IP${NC}"
echo ""

echo -e "${YELLOW}[端口转发方案]${NC}"
echo -e "  localhost:33013 -> $CONTAINER_IP:8000"
echo ""

# 检查 socat
echo -e "${YELLOW}[1/4] 检查 socat...${NC}"
if ! kubectl exec -n $NAMESPACE $OPENHANDS_POD -- command -v socat &>/dev/null; then
    echo -e "${YELLOW}⚠ socat 未安装，正在安装...${NC}"
    kubectl exec -n $NAMESPACE $OPENHANDS_POD -- apk add --no-cache socat
    echo -e "${GREEN}✓ socat 安装完成${NC}"
else
    echo -e "${GREEN}✓ socat 已安装${NC}"
fi
echo ""

# 停止旧的 socat 进程
echo -e "${YELLOW}[2/4] 停止旧的 socat 进程...${NC}"
kubectl exec -n $NAMESPACE $OPENHANDS_POD -- pkill -f "socat.*33013" 2>/dev/null || echo -e "${YELLOW}⚠ 没有运行中的 socat 进程${NC}"
echo -e "${GREEN}✓ 旧进程已清理${NC}"
echo ""

# 启动端口转发
echo -e "${YELLOW}[3/4] 启动端口转发...${NC}"
kubectl exec -n $NAMESPACE $OPENHANDS_POD -- nohup socat TCP-LISTEN:33013,fork,reuseaddr TCP-connect:$CONTAINER_IP:8000 > /tmp/socat.log 2>&1 &
sleep 2

# 检查 socat 是否运行
if kubectl exec -n $NAMESPACE $OPENHANDS_POD -- ps aux | grep -q "[s]ocat.*33013"; then
    echo -e "${GREEN}✓ socat 端口转发已启动${NC}"
else
    echo -e "${RED}✗ socat 启动失败${NC}"
    echo -e "${YELLOW}查看日志:${NC}"
    kubectl exec -n $NAMESPACE $OPENHANDS_POD -- cat /tmp/socat.log
    exit 1
fi
echo ""

# 测试连接
echo -e "${YELLOW}[4/4] 测试连接...${NC}"
sleep 2
if kubectl exec -n $NAMESPACE $OPENHANDS_POD -- sh -c "nc -zv localhost 33013" 2>/dev/null; then
    echo -e "${GREEN}✓ localhost:33013 连接成功！${NC}"
    echo ""
    echo -e "${GREEN}修复完成！${NC}"
    echo ""
    echo -e "${YELLOW}现在可以:${NC}"
    echo "  1. 访问 OpenHands Web UI"
    echo "  2. 创建新会话或重试现有会话"
    echo "  3. 会话应该可以正常工作"
else
    echo -e "${RED}✗ localhost:33013 连接失败${NC}"
    echo -e "${YELLOW}尝试直接连接到容器...${NC}"
    if kubectl exec -n $NAMESPACE $OPENHANDS_POD -- sh -c "nc -zv $CONTAINER_IP 8000" 2>/dev/null; then
        echo -e "${GREEN}✓ 可以直接连接到 $CONTAINER_IP:8000${NC}"
        echo -e "${YELLOW}socat 配置可能有问题${NC}"
        echo -e "${YELLOW}查看 socat 日志:${NC}"
        kubectl exec -n $NAMESPACE $OPENHANDS_POD -- cat /tmp/socat.log
    else
        echo -e "${RED}✗ 无法连接到 $CONTAINER_IP:8000${NC}"
        echo -e "${YELLOW}agent-server 可能未正确启动${NC}"
    fi
    exit 1
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}socat 端口转发状态${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
kubectl exec -n $NAMESPACE $OPENHANDS_POD -- ps aux | grep socat
echo ""
echo -e "${YELLOW}⚠ 注意: socat 进程会在 OpenHands Pod 重启后失效${NC}"
echo -e "${YELLOW}  这是临时修复方案${NC}"
echo ""
echo -e "${GREEN}查看 socat 日志:${NC}"
echo -e "  kubectl exec -n $NAMESPACE $OPENHANDS_POD -- tail -f /tmp/socat.log"
echo ""
echo -e "${GREEN}查看 agent-server 日志:${NC}"
echo -e "  kubectl exec -n $NAMESPACE $DIND_POD -- docker logs -f $AGENT_CONTAINER"
echo ""
