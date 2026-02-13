#!/bin/bash

# OpenHands 一键部署脚本（DinD 模式）
# 使用方法：
#   ./deploy-opnhands-dind.sh

set -e

# 配置变量
NAMESPACE="openhands-dev"
HELM_RELEASE="openhands"
CHART_PATH="./openhands"
DOCKER_HOST="docker-dind.openhands-dev.svc.cluster.local:2375"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}OpenHands DinD 模式一键部署脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 检查 kubectl
echo -e "${YELLOW}[1/8] 检查 kubectl...${NC}"
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl 未安装${NC}"
    exit 1
fi
echo -e "${GREEN}✓ kubectl 已安装${NC}"

# 检查 helm
echo -e "${YELLOW}[2/8] 检查 helm...${NC}"
if ! command -v helm &> /dev/null; then
    echo -e "${RED}✗ helm 未安装${NC}"
    exit 1
fi
echo -e "${GREEN}✓ helm 已安装${NC}"

# 检查命名空间
echo -e "${YELLOW}[3/8] 检查命名空间 $NAMESPACE...${NC}"
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${YELLOW}✗ 命名空间不存在，正在创建...${NC}"
    kubectl create namespace $NAMESPACE
fi
echo -e "${GREEN}✓ 命名空间 $NAMESPACE 已存在${NC}"

# 检查 DinD 服务
echo -e "${YELLOW}[4/8] 检查 DinD 服务...${NC}"
if ! kubectl get svc docker-dind -n $NAMESPACE &> /dev/null; then
    echo -e "${RED}✗ DinD 服务不存在，请先部署 DinD${NC}"
    echo -e "${YELLOW}提示：使用 kubectl apply -f dind-service.yaml 部署 DinD${NC}"
    exit 1
fi
echo -e "${GREEN}✓ DinD 服务存在${NC}"

# 获取 DinD Service 信息
DIND_SVC=$(kubectl get svc docker-dind -n $NAMESPACE -o json)
DIND_PORT=$(echo $DIND_SVC | jq -r '.spec.ports[0].port')
echo -e "${GREEN}  - DinD Service: docker-dind.$NAMESPACE.svc.cluster.local:$DIND_PORT${NC}"

# 检查 DinD Pods
echo -e "${YELLOW}[5/8] 检查 DinD Pods...${NC}"
DIND_PODS=$(kubectl get pods -n $NAMESPACE -l app=docker-dind -o json)
DIND_READY=$(echo $DIND_PODS | jq -r '.items[] | select(.status.phase=="Running") | .status.containerStatuses[0].ready' | grep -c true || echo 0)
DIND_TOTAL=$(echo $DIND_PODS | jq -r '.items | length')

if [ "$DIND_READY" -lt "$DIND_TOTAL" ]; then
    echo -e "${YELLOW}⚠ DinD Pods 未全部就绪 ($DIND_READY/$DIND_TOTAL)${NC}"
    echo -e "${YELLOW}  继续部署，但可能需要等待 DinD 就绪...${NC}"
else
    echo -e "${GREEN}✓ DinD Pods 就绪 ($DIND_READY/$DIND_TOTAL)${NC}"
fi

# 获取 LLM API Key
echo ""
echo -e "${YELLOW}[6/8] 配置 LLM API Key...${NC}"
read -p "请输入 OpenAI API Key (格式: sk-...): " API_KEY
if [ -z "$API_KEY" ]; then
    echo -e "${RED}✗ API Key 不能为空${NC}"
    exit 1
fi

# 询问 LLM Model
read -p "LLM Model (默认: gpt-4o): " MODEL
MODEL=${MODEL:-gpt-4o}

# 询问 Base URL
read -p "Base URL (可选，直接回车跳过): " BASE_URL

echo -e "${GREEN}✓ LLM 配置: model=$MODEL${NC}"

# 部署 OpenHands
echo ""
echo -e "${YELLOW}[7/8] 部署 OpenHands...${NC}"
cd /workspace/project/OpenHands/helm

# 检查是否已安装（使用 helm list -q 只输出 NAME 列，避免匹配到 NAMESPACE）
if helm list -n $NAMESPACE -q | grep -q "^${HELM_RELEASE}$"; then
    echo -e "${YELLOW}  发现已有部署，执行升级...${NC}"
    
    if [ -z "$BASE_URL" ]; then
        helm upgrade $HELM_RELEASE $CHART_PATH \
            -f ./$CHART_PATH/values.yaml \
            -f ./$CHART_PATH/values-k8s-production.yaml \
            -n $NAMESPACE \
            --set openhands.llm.apiKey="$API_KEY" \
            --set openhands.llm.model="$MODEL" \
            --reuse-values
    else
        helm upgrade $HELM_RELEASE $CHART_PATH \
            -f ./$CHART_PATH/values.yaml \
            -f ./$CHART_PATH/values-k8s-production.yaml \
            -n $NAMESPACE \
            --set openhands.llm.apiKey="$API_KEY" \
            --set openhands.llm.model="$MODEL" \
            --set openhands.llm.baseURL="$BASE_URL" \
            --reuse-values
    fi
else
    echo -e "${YELLOW}  执行全新安装...${NC}"
    
    if [ -z "$BASE_URL" ]; then
        helm install $HELM_RELEASE $CHART_PATH \
            -f ./$CHART_PATH/values.yaml \
            -f ./$CHART_PATH/values-k8s-production.yaml \
            -n $NAMESPACE \
            --set openhands.llm.apiKey="$API_KEY" \
            --set openhands.llm.model="$MODEL"
    else
        helm install $HELM_RELEASE $CHART_PATH \
            -f ./$CHART_PATH/values.yaml \
            -f ./$CHART_PATH/values-k8s-production.yaml \
            -n $NAMESPACE \
            --set openhands.llm.apiKey="$API_KEY" \
            --set openhands.llm.model="$MODEL" \
            --set openhands.llm.baseURL="$BASE_URL"
    fi
fi

echo -e "${GREEN}✓ Helm 部署成功${NC}"

# 等待 Pod 就绪
echo ""
echo -e "${YELLOW}[8/8] 等待 OpenHands Pod 就绪...${NC}"
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=$HELM_RELEASE \
    -n $NAMESPACE \
    --timeout=300s

echo -e "${GREEN}✓ OpenHands Pod 已就绪${NC}"

# 验证部署
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}验证部署${NC}"
echo -e "${GREEN}========================================${NC}"

# 获取 Pod 名称
OPENHANDS_POD=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=$HELM_RELEASE -o jsonpath='{.items[0].metadata.name}')

echo -e "${YELLOW}检查环境变量...${NC}"
DOCKER_HOST_ENV=$(kubectl exec -n $NAMESPACE $OPENHANDS_POD -- env | grep DOCKER_HOST | grep DOCKER_TLS_CERTDIR)
if [ -n "$DOCKER_HOST_ENV" ]; then
    echo -e "${GREEN}✓ DOCKER 环境变量已设置${NC}"
    echo -e "  $DOCKER_HOST_ENV"
else
    echo -e "${RED}✗ DOCKER 环境变量未设置${NC}"
    exit 1
fi

echo -e "${YELLOW}测试 Docker 连接...${NC}"
if kubectl exec -n $NAMESPACE $OPENHANDS_POD -- docker version &> /dev/null; then
    echo -e "${GREEN}✓ Docker 连接成功${NC}"
else
    echo -e "${RED}✗ Docker 连接失败${NC}"
    echo -e "${YELLOW}提示：检查 DinD 服务是否正常运行${NC}"
    exit 1
fi

echo -e "${YELLOW}测试创建容器...${NC}"
if kubectl exec -n $NAMESPACE $OPENHANDS_POD -- docker run --rm hello-world &> /dev/null; then
    echo -e "${GREEN}✓ 容器创建成功${NC}"
else
    echo -e "${RED}✗ 容器创建失败${NC}"
    exit 1
fi

# 显示访问信息
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}部署完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}OpenHands 信息：${NC}"
echo -e "  命名空间: $NAMESPACE"
echo -e "  Pod 名称: $OPENHANDS_POD"
echo ""
echo -e "${GREEN}访问方式：${NC}"
echo -e "  方式 1 (Port Forward):"
echo -e "    kubectl port-forward -n $NAMESPACE svc/$HELM_RELEASE 3000:3000"
echo -e "    浏览器访问: http://localhost:3000"
echo ""
echo -e "  方式 2 (NodePort):"
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
NODE_PORT=$(kubectl get svc $HELM_RELEASE -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
echo -e "    浏览器访问: http://$NODE_IP:$NODE_PORT"
echo ""
echo -e "${GREEN}查看会话容器：${NC}"
echo -e "  DIND_POD=\$(kubectl get pod -n $NAMESPACE -l app=docker-dind -o jsonpath='{.items[0].metadata.name}')"
echo -e "  kubectl exec -n $NAMESPACE \$DIND_POD -- docker ps"
echo ""
echo -e "${GREEN}查看日志：${NC}"
echo -e "  kubectl logs -f -n $NAMESPACE $OPENHANDS_POD"
echo ""
echo -e "${GREEN}完整文档：${NC}"
echo -e "  - 部署指南: /workspace/project/OpenHands/helm/openhands/README_DIND_DEPLOYMENT.md"
echo -e "  - 命令速查: /workspace/project/OpenHands/helm/OPENHANDS_HELM_COMMANDS.md"
echo ""
echo -e "${GREEN}========================================${NC}"
