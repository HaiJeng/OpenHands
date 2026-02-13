#!/bin/bash
# OpenHands DinD 部署故障排查脚本

echo "=========================================="
echo "OpenHands DinD 故障排查"
echo "=========================================="
echo ""

NAMESPACE="openhands-dev"

# 1. 检查环境变量
echo "[1/7] 检查环境变量"
OPENHANDS_POD=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')
echo "OpenHands Pod: $OPENHANDS_POD"

DOCKER_ENV=$(kubectl exec -n $NAMESPACE $OPENHANDS_POD -- env | grep "^DOCKER_HOST\|^DOCKER_TLS")
if [ -n "$DOCKER_ENV" ]; then
    echo "✓ Docker 环境变量已设置："
    kubectl exec -n $NAMESPACE $OPENHANDS_POD -- env | grep "^DOCKER_HOST\|^DOCKER_TLS"
else
    echo "✗ Docker 环境变量未设置"
    exit 1
fi
echo ""

# 2. 测试 Docker 连接
echo "[2/7] 测试 Docker 连接"
if kubectl exec -n $NAMESPACE $OPENHANDS_POD -- docker version &> /dev/null; then
    echo "✓ Docker 连接成功"
    kubectl exec -n $NAMESPACE $OPENHANDS_POD -- docker version | grep "Server.*Version"
else
    echo "✗ Docker 连接失败"
    kubectl exec -n $NAMESPACE $OPENHANDS_POD -- docker version
    exit 1
fi
echo ""

# 3. 检查已有镜像
echo "[3/7] 检查已有镜像"
IMAGES=$(kubectl exec -n $NAMESPACE $OPENHANDS_POD -- docker images --format "{{.Repository}}:{{.Tag}}" | grep agent-server)
if [ -n "$IMAGES" ]; then
    echo "✓ 已有 agent-server 镜像："
    kubectl exec -n $NAMESPACE $OPENHANDS_POD -- docker images --format "{{.Repository}}:{{.Tag}} ({{.Size}})" | grep agent-server
else
    echo "✗ 没有 agent-server 镜像"
fi
echo ""

# 4. 检查 DinD 容器
echo "[4/7] 检查 DinD 中的会话容器"
DIND_POD=$(kubectl get pod -n $NAMESPACE -l app=docker-dind -o jsonpath='{.items[0].metadata.name}')
echo "DinD Pod: $DIND_POD"

CONTAINERS=$(kubectl exec -n $NAMESPACE $DIND_POD -- docker ps --format "{{.Names}} ({{.Image}})" | grep -v "^docker-dind")
if [ -n "$CONTAINERS" ]; then
    echo "✓ 发现会话容器："
    kubectl exec -n $NAMESPACE $DIND_POD -- docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | grep -v "^NAMES"
else
    echo "✗ 没有会话容器"
fi
echo ""

# 5. 测试拉取镜像
echo "[5/7] 测试拉取镜像（可能需要几分钟）"
if kubectl exec -n $NAMESPACE $OPENHANDS_POD -- docker pull ghcr.io/openhands/agent-server:b7d5cdb-python; then
    echo "✓ 镜像拉取成功"
else
    echo "✗ 镜像拉取失败"
    echo "  可能原因："
    echo "  - 网络问题，无法访问 ghcr.io"
    echo "  - 镜像不存在或标签错误"
    echo "  - 需要认证"
fi
echo ""

# 6. 查看 OpenHands 日志
echo "[6/7] 查看 OpenHands 最新日志（最后 50 行）"
echo "--- 日志开始 ---"
kubectl logs -n $NAMESPACE $OPENHANDS_POD --tail=50 | grep -v "INFO.*192.168"
echo "--- 日志结束 ---"
echo ""

# 7. 检查网络连接
echo "[7/7] 检查网络连接"
echo "测试到 DinD 服务的连接："
if kubectl exec -n $NAMESPACE $OPENHANDS_POD -- nc -zv docker-dind.$NAMESPACE.svc.cluster.local 2375 2>&1 | grep -q "succeeded"; then
    echo "✓ 可以连接到 DinD 服务"
else
    echo "✗ 无法连接到 DinD 服务"
fi
echo ""

echo "=========================================="
echo "故障排查完成"
echo "=========================================="
echo ""
echo "如果以上都正常，请手动测试创建会话："
echo "  1. 访问 OpenHands Web UI"
echo "  2. 创建新会话"
echo "  3. 运行以下命令查看容器："
echo "     kubectl exec -n $NAMESPACE $DIND_POD -- docker ps"
echo ""
