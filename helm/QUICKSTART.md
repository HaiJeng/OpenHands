# 🚀 OpenHands Kubernetes Runtime - 快速开始

## ✅ 准备工作

### 1. 检查 Kubernetes 集群

```bash
kubectl cluster-info
kubectl get nodes
kubectl get storageclass
```

### 2. 设置变量

```bash
# 命名空间
export NAMESPACE="openhands"

# 生成密钥
export JWT_SECRET=$(openssl rand -base64 32 | tr -d '/+=')
export SECRET_KEY=$(openssl rand -base64 32 | tr -d '/+=')

# LLM API Key（替换为实际密钥）
export LLM_API_KEY="sk-your-actual-api-key"

# 验证
echo "JWT: ${JWT_SECRET:0:8}..."
echo "KEY: ${SECRET_KEY:0:8}..."
echo "API: ${LLM_API_KEY:0:15}..."
```

## 🎯 一键部署

### 方式1：生产配置（推荐）

```bash
cd /workspace/project/OpenHands/helm

# 部署
helm install openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace $NAMESPACE \
  --create-namespace \
  --set openhands.llm.apiKey="$LLM_API_KEY" \
  --set openhands.jwtSecret="$JWT_SECRET" \
  --set openhands.secretKey="$SECRET_KEY" \
  --timeout 10m \
  --wait
```

### 方式2：使用您的自定义配置

```bash
cd /workspace/project/OpenHands/helm

# 部署（合并 my-values.yaml）
helm install openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  -f /workspace/my-values.yaml \
  --namespace $NAMESPACE \
  --create-namespace \
  --set openhands.llm.apiKey="$LLM_API_KEY" \
  --set openhands.jwtSecret="$JWT_SECRET" \
  --set openhands.secretKey="$SECRET_KEY" \
  --timeout 10m \
  --wait
```

## ✅ 验证部署

```bash
# 检查 Pod
kubectl get pods -n $NAMESPACE

# 检查 Service
kubectl get svc -n $NAMESPACE

# 检查日志
kubectl logs -f deployment/openhands -n $NAMESPACE
```

## 🌐 访问 OpenHands

### 方式1：NodePort（最简单）

```bash
# 获取 NodePort
NODE_PORT=$(kubectl get svc openhands -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')

echo "访问地址: http://$NODE_IP:$NODE_PORT"
```

### 方式2：Port Forward

```bash
# 转发端口
kubectl port-forward svc/openhands 3000:3000 -n $NAMESPACE

# 访问: http://localhost:3000
```

## 📊 关键配置

### Kubernetes Runtime ✅
```yaml
openhands:
  sandbox:
    runtime: kubernetes  # ✅ 不需要 Docker socket
```

### Docker Socket ❌
```yaml
dockerSocket:
  enabled: false  # ✅ 已禁用
```

### 资源配置
```yaml
resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2
    memory: 2Gi
```

## 🔍 故障排除

### Pod 无法启动
```bash
kubectl describe pod <pod-name> -n $NAMESPACE
kubectl logs <pod-name> -n $NAMESPACE
```

### 镜像拉取失败
```bash
# 检查镜像配置
kubectl get deployment openhands -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### PVC 绑定失败
```bash
kubectl get pvc -n $NAMESPACE
kubectl describe pvc -n $NAMESPACE
```

## 📖 完整文档

- **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)** - 完整部署指南
- **[K8S_RUNTIME_GUIDE.md](./K8S_RUNTIME_GUIDE.md)** - Kubernetes runtime 指南
- **[values-k8s-production.yaml](./openhands/values-k8s-production.yaml)** - 生产配置文件

## 🎉 部署成功！

现在您可以通过 NodePort 或 Port Forward 访问 OpenHands 了！

**注意**: 
- 确保替换 `LLM_API_KEY` 为实际的 API Key
- 可以根据需要调整资源配置
- 生产环境建议配置 Ingress 和 TLS

---

**问题？** 查看完整文档或运行：
```bash
kubectl logs -f deployment/openhands -n $NAMESPACE
```
