#!/bin/bash
# 测试从 OpenHands Pod 到 agent-server 的连接
# 不需要 socat，直接测试现有连接

NAMESPACE="openhands-dev"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}测试 agent-server 连接${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

OPENHANDS_POD=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')
DIND_POD=$(kubectl get pod -n $NAMESPACE -l app=docker-dind -o jsonpath='{.items[0].metadata.name}')
AGENT_CONTAINER=$(kubectl exec -n $NAMESPACE $DIND_POD -- docker ps --filter "name=agent-server" --format "{{.ID}}" | head -1)
CONTAINER_IP=$(kubectl exec -n $NAMESPACE $DIND_POD -- docker inspect $AGENT_CONTAINER --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')

echo -e "${GREEN}OpenHands Pod: $OPENHANDS_POD${NC}"
echo -e "${GREEN}DinD Pod: $DIND_POD${NC}"
echo -e "${GREEN}Agent Container: $AGENT_CONTAINER${NC}"
echo -e "${GREEN}Container IP: $CONTAINER_IP${NC}"
echo ""

# 测试 1: 从 DinD Pod 测试 localhost:33013（映射后的端口）
echo -e "${YELLOW}[测试 1] 从 DinD Pod 测试 localhost:33013${NC}"
if kubectl exec -n $NAMESPACE $DIND_POD -- sh -c "timeout 3 nc -zv localhost 33013" 2>/dev/null; then
    echo -e "${GREEN}✓ DinD Pod 可以连接 localhost:33013${NC}"
    echo -e "${BLUE}  这意味着端口映射工作正常${NC}"
else
    echo -e "${RED}✗ DinD Pod 无法连接 localhost:33013${NC}"
fi
echo ""

# 测试 2: 从 DinD Pod 测试容器 IP:8000（直接访问容器）
echo -e "${YELLOW}[测试 2] 从 DinD Pod 测试 $CONTAINER_IP:8000${NC}"
if kubectl exec -n $NAMESPACE $DIND_POD -- sh -c "timeout 3 nc -zv $CONTAINER_IP 8000" 2>/dev/null; then
    echo -e "${GREEN}✓ DinD Pod 可以连接 $CONTAINER_IP:8000${NC}"
    echo -e "${BLUE}  这意味着 agent-server 正常监听在容器内部${NC}"
else
    echo -e "${RED}✗ DinD Pod 无法连接 $CONTAINER_IP:8000${NC}"
fi
echo ""

# 测试 3: 从 OpenHands Pod 测试 DinD Pod IP:33013（跨 Pod 访问）
echo -e "${YELLOW}[测试 3] 从 OpenHands Pod 测试 DinD Pod IP:33013${NC}"
DIND_POD_IP=$(kubectl get pod -n $NAMESPACE $DIND_POD -o jsonpath='{.status.podIP}')
echo -e "${BLUE}DinD Pod IP: $DIND_POD_IP${NC}"
if kubectl exec -n $NAMESPACE $OPENHANDS_POD -- sh -c "timeout 3 nc -zv $DIND_POD_IP 33013" 2>/dev/null; then
    echo -e "${GREEN}✓ OpenHands Pod 可以连接 $DIND_POD_IP:33013${NC}"
    echo -e "${BLUE}  这可以作为一个解决方案！${NC}"
else
    echo -e "${RED}✗ OpenHands Pod 无法连接 $DIND_POD_IP:33013${NC}"
fi
echo ""

# 测试 4: 从 OpenHands Pod 测试 localhost:33013（当前配置）
echo -e "${YELLOW}[测试 4] 从 OpenHands Pod 测试 localhost:33013${NC}"
if kubectl exec -n $NAMESPACE $OPENHANDS_POD -- sh -c "timeout 3 nc -zv localhost 33013" 2>/dev/null; then
    echo -e "${GREEN}✓ OpenHands Pod 可以连接 localhost:33013${NC}"
    echo -e "${BLUE}  问题应该已经解决！${NC}"
else
    echo -e "${RED}✗ OpenHands Pod 无法连接 localhost:33013${NC}"
    echo -e "${BLUE}  这是当前问题的根源${NC}"
fi
echo ""

# 建议
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}解决方案${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if kubectl exec -n $NAMESPACE $DIND_POD -- sh -c "timeout 3 nc -zv localhost 33013" 2>/dev/null; then
    echo -e "${GREEN}✓ 端口映射在 DinD Pod 内正常工作${NC}"
    echo ""
    echo -e "${YELLOW}解决方案: 使用 socat 在 OpenHands Pod 内建立端口转发${NC}"
    echo ""
    echo "运行以下命令："
    echo "  kubectl exec -it -n $NAMESPACE $OPENHANDS_POD -- sh"
    echo "  apk add --no-cache socat"
    echo "  nohup socat TCP-LISTEN:33013,fork,reuseaddr TCP-CONNECT:$DIND_POD_IP:33013 > /tmp/socat.log 2>&1 &"
    echo ""
else
    echo -e "${RED}✗ 端口映射在 DinD Pod 内也不工作${NC}"
    echo ""
    echo -e "${YELLOW}解决方案: 直接连接到容器 IP:8000${NC}"
    echo ""
    echo "运行以下命令："
    echo "  kubectl exec -it -n $NAMESPACE $OPENHANDS_POD -- sh"
    echo "  apk add --no-cache socat"
    echo "  nohup socat TCP-LISTEN:33013,fork,reuseaddr TCP-CONNECT:$CONTAINER_IP:8000 > /tmp/socat.log 2>&1 &"
    echo ""
fi
