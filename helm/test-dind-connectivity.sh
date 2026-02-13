#!/bin/bash
# 测试从 OpenHands Pod 访问 DinD Pod 和 agent-server 容器

NAMESPACE="openhands-dev"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}DinD 连接性测试${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 获取 Pod 信息
OPENHANDS_POD=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')
DIND_POD=$(kubectl get pod -n $NAMESPACE -l app=docker-dind -o jsonpath='{.items[0].metadata.name}')
DIND_POD_IP=$(kubectl get pod -n $NAMESPACE $DIND_POD -o jsonpath='{.status.podIP}')
DIND_SVC_IP=$(kubectl get svc docker-dind -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')

echo -e "${GREEN}OpenHands Pod: $OPENHANDS_POD${NC}"
echo -e "${GREEN}DinD Pod: $DIND_POD${NC}"
echo -e "${GREEN}DinD Pod IP: $DIND_POD_IP${NC}"
echo -e "${GREEN}DinD Service IP: $DIND_SVC_IP${NC}"
echo ""

# 获取 agent-server 容器
AGENT_CONTAINER=$(kubectl exec -n $NAMESPACE $DIND_POD -- docker ps --filter "name=agent-server" --format "{{.ID}}" | head -1)
CONTAINER_IP=$(kubectl exec -n $NAMESPACE $DIND_POD -- docker inspect $AGENT_CONTAINER --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{.end}}')

echo -e "${GREEN}Agent Container: $AGENT_CONTAINER${NC}"
echo -e "${GREEN}Container IP: $CONTAINER_IP${NC}"
echo ""

echo -e "${YELLOW}测试 1: 从 OpenHands Pod 测试 DinD Pod IP:33013${NC}"
if kubectl exec -n $NAMESPACE $OPENHANDS_POD -- sh -c "timeout 3 nc -zv $DIND_POD_IP 33013" 2>/dev/null; then
    echo -e "${GREEN}✓ 可以连接到 $DIND_POD_IP:33013${NC}"
    echo -e "${BLUE}  → 这是最佳解决方案！使用 DinD Pod IP${NC}"
    SUCCESS_DIND_POD=true
else
    echo -e "${RED}✗ 无法连接到 $DIND_POD_IP:33013${NC}"
    SUCCESS_DIND_POD=false
fi
echo ""

echo -e "${YELLOW}测试 2: 从 OpenHands Pod 测试 DinD Service IP:33013${NC}"
if kubectl exec -n $NAMESPACE $OPENHANDS_POD -- sh -c "timeout 3 nc -zv $DIND_SVC_IP 33013" 2>/dev/null; then
    echo -e "${GREEN}✓ 可以连接到 $DIND_SVC_IP:33013${NC}"
    echo -e "${BLUE}  → 使用 Kubernetes Service IP${NC}"
    SUCCESS_DIND_SVC=true
else
    echo -e "${RED}✗ 无法连接到 $DIND_SVC_IP:33013${NC}"
    SUCCESS_DIND_SVC=false
fi
echo ""

echo -e "${YELLOW}测试 3: 从 OpenHands Pod 测试容器 IP:8000${NC}"
if kubectl exec -n $NAMESPACE $OPENHANDS_POD -- sh -c "timeout 3 nc -zv $CONTAINER_IP 8000" 2>/dev/null; then
    echo -e "${GREEN}✓ 可以连接到 $CONTAINER_IP:8000${NC}"
    echo -e "${BLUE}  → 直接访问容器 IP（需要路由）${NC}"
    SUCCESS_CONTAINER=true
else
    echo -e "${RED}✗ 无法连接到 $CONTAINER_IP:8000${NC}"
    echo -e "${YELLOW}  → 容器网络需要 Docker bridge 路由${NC}"
    SUCCESS_CONTAINER=false
fi
echo ""

echo -e "${YELLOW}测试 4: 从 DinD Pod 内部测试 localhost:33013${NC}"
if kubectl exec -n $NAMESPACE $DIND_POD -- sh -c "timeout 3 nc -zv localhost 33013" 2>/dev/null; then
    echo -e "${GREEN}✓ DinD Pod 可以访问 localhost:33013${NC}"
    echo -e "${BLUE}  → Docker 端口映射在 DinD 内部工作${NC}"
    SUCCESS_DIND_LOCALHOST=true
else
    echo -e "${RED}✗ DinD Pod 无法访问 localhost:33013${NC}"
    SUCCESS_DIND_LOCALHOST=false
fi
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}推荐解决方案${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ "$SUCCESS_DIND_POD" = true ]; then
    echo -e "${GREEN}✅ 方案 1: 使用 DinD Pod IP（推荐）${NC}"
    echo ""
    echo "在 OpenHands 配置中设置环境变量："
    echo "  SANDBOX_HOST=$DIND_POD_IP"
    echo "  SANDBOX_PORT=33013"
    echo ""
    echo "或修改 OpenHands 启动参数，连接到："
    echo "  http://$DIND_POD_IP:33013"
    echo ""
elif [ "$SUCCESS_DIND_SVC" = true ]; then
    echo -e "${GREEN}✅ 方案 2: 使用 DinD Service IP${NC}"
    echo ""
    echo "连接到："
    echo "  http://$DIND_SVC_IP:33013"
    echo ""
elif [ "$SUCCESS_CONTAINER" = true ]; then
    echo -e "${GREEN}✅ 方案 3: 直接访问容器（需要 socat）${NC}"
    echo ""
    echo "使用 socat 转发："
    echo "  localhost:33013 -> $CONTAINER_IP:8000"
    echo ""
    echo "运行："
    echo "  ./socat-fix.sh"
    echo ""
elif [ "$SUCCESS_DIND_LOCALHOST" = true ]; then
    echo -e "${GREEN}✅ 方案 4: 从 DinD Pod 内部访问${NC}"
    echo ""
    echo "需要在 DinD Pod 内运行代理"
    echo "（不推荐，复杂度高）"
    echo ""
else
    echo -e "${RED}❌ 所有连接测试失败${NC}"
    echo ""
    echo "可能的问题："
    echo "  1. agent-server 容器未正确启动"
    echo "  2. 端口映射配置错误"
    echo "  3. Kubernetes 网络策略限制"
    echo ""
    echo "建议："
    echo "  1. 重启 OpenHands Pod"
    echo "  2. 查看详细日志"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}下一步操作${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}1. 运行连接测试:${NC}"
echo "   ./test-dind-connectivity.sh"
echo ""
echo -e "${GREEN}2. 根据测试结果选择修复方案${NC}"
echo ""
echo -e "${GREEN}3. 如果都不行，使用 socat 临时修复:${NC}"
echo "   ./socat-fix.sh"
echo ""
