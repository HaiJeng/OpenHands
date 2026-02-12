# OpenHands Helm Chart - 快速使用指南

本指南将帮助你快速使用 Helm 部署 OpenHands 到 Kubernetes 集群。

## 📋 前置条件

1. 安装 `kubectl` - Kubernetes 命令行工具
2. 安装 `helm` - Kubernetes 包管理器（版本 3.0+）
3. 访问一个可用的 Kubernetes 集群

## 🚀 快速开始

### 1. 安装 Helm Chart

```bash
# 从本地 chart 安装
cd OpenHands/helm/openhands

# 使用默认配置安装
helm install openhands . \
  --set openhands.llm.apiKey=your-api-key-here \
  --set openhands.llm.model=gpt-4o
```

### 2. 等待 Pod 启动

```bash
# 查看 Pod 状态
kubectl get pods -l app.kubernetes.io/name=openhands -w

# 查看 Pod 日志
kubectl logs -l app.kubernetes.io/name=openhands --tail=100 -f
```

### 3. 访问 OpenHands

#### 方式 1: Port Forward（本地测试）

```bash
kubectl port-forward svc/openhands 3000:3000

# 然后在浏览器中访问
open http://localhost:3000
```

#### 方式 2: LoadBalancer（云环境）

```bash
# 如果是云环境，可以改为 LoadBalancer
helm upgrade openhands . --set service.type=LoadBalancer

# 获取外部 IP
kubectl get svc openhands

# 访问 http://<EXTERNAL-IP>:3000
```

#### 方式 3: Ingress（生产环境）

```bash
# 启用 Ingress
helm upgrade openhands . \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.hosts[0].host=openhands.yourdomain.com \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix

# 配置 DNS 指向 Ingress IP
# 然后访问 http://openhands.yourdomain.com
```

## 🔧 自定义镜像 Tag（重点）

OpenHands Helm Chart 允许你完全控制所有使用的镜像版本。

### 通过命令行参数指定

```bash
helm install openhands . \
  --set image.tag=v0.0.1 \
  --set image.runtime.tag=v0.0.1-runtime \
  --set image.agentServer.tag=v0.0.1-agent \
  --set image.uv.tag=latest \
  --set openhands.llm.apiKey=sk-... \
  --set openhands.llm.model=gpt-4o
```

### 通过自定义 values 文件

创建一个 `my-values.yaml` 文件：

```yaml
image:
  repository: docker.openhands.dev/openhands/openhands
  tag: v0.0.1  # 主应用版本
  
  runtime:
    repository: ghcr.io/openhands/runtime
    tag: v0.0.1-runtime  # Runtime 版本
    
  agentServer:
    repository: ghcr.io/openhands/agent-server
    tag: v0.0.1-agent  # Agent Server 版本
    
  uv:
    repository: ghcr.io/astral-sh/uv
    tag: latest  # UV 版本

openhands:
  llm:
    model: gpt-4o
    apiKey: sk-your-api-key-here
```

然后使用自定义 values 安装：

```bash
helm install openhands . -f my-values.yaml
```

## 📦 生产环境部署

### 1. 创建 Secret 存储敏感信息

```bash
# 生成 JWT 密钥
JWT_SECRET=$(openssl rand -base64 32)

# 创建 Secret
kubectl create secret generic openhands-secrets \
  --from-literal=llmApiKey=sk-your-api-key-here \
  --from-literal=jwtSecret=$JWT_SECRET
```

### 2. 使用生产配置

```bash
# 使用提供的生产配置示例
helm install openhands . \
  -f values-production-example.yaml \
  --set secret.enabled=true \
  --set secret.existingSecret=openhands-secrets
```

### 3. 启用持久化存储

```bash
# 使用现有的存储类（如 fast-ssd）
helm upgrade openhands . \
  --set persistence.storageClass=fast-ssd \
  --set persistence.size=100Gi
```

### 4. 配置 Ingress 和 TLS

```bash
# 安装 cert-manager（如果还没有）
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# 启用 Ingress 和 TLS
helm upgrade openhands . \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod \
  --set ingress.hosts[0].host=openhands.yourdomain.com \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix \
  --set ingress.tls[0].secretName=openhands-tls \
  --set ingress.tls[0].hosts[0]=openhands.yourdomain.com
```

## 🔍 监控和调试

### 查看资源状态

```bash
# 查看 Pod
kubectl get pods -l app.kubernetes.io/name=openhands

# 查看 Service
kubectl get svc openhands

# 查看 PVC
kubectl get pvc -l app.kubernetes.io/name=openhands

# 查看 Ingress
kubectl get ingress openhands
```

### 查看日志

```bash
# 查看所有 Pod 日志
kubectl logs -l app.kubernetes.io/name=openhands --tail=100 -f

# 查看特定 Pod 日志
kubectl logs <pod-name> --tail=100 -f

# 查看之前的容器日志（如果 Pod 重启了）
kubectl logs <pod-name> --previous
```

### 进入 Pod 调试

```bash
# 获取 Pod 名称
POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')

# 进入 Pod
kubectl exec -it $POD_NAME -- /bin/bash

# 或者只执行一个命令
kubectl exec -it $POD_NAME -- env | sort
kubectl exec -it $POD_NAME -- ps aux
```

### 查看事件

```bash
# 查看命名空间的事件
kubectl get events --sort-by='.lastTimestamp'

# 查看 OpenHands 相关的事件
kubectl get events --field-selector involvedObject.name=openhands
```

## 🔄 更新和维护

### 更新镜像版本

```bash
# 更新到新版本
helm upgrade openhands . \
  --set image.tag=v0.0.2 \
  --set image.runtime.tag=v0.0.2-runtime \
  --set image.agentServer.tag=v0.0.2-agent

# 查看升级状态
helm status openhands
```

### 回滚到之前的版本

```bash
# 查看历史版本
helm history openhands

# 回滚到上一个版本
helm rollback openhands

# 回滚到特定版本
helm rollback openhands 2
```

### 扩容/缩容

```bash
# 手动扩容到 3 个副本
helm upgrade openhands . --set replicaCount=3

# 启用自动扩容
helm upgrade openhands . \
  --set autoscaling.enabled=true \
  --set autoscaling.minReplicas=2 \
  --set autoscaling.maxReplicas=10 \
  --set autoscaling.targetCPUUtilizationPercentage=70
```

## 🗑️ 卸载

```bash
# 删除 Helm release
helm uninstall openhands

# 删除 PVC（如果需要）
kubectl delete pvc openhands-data

# 删除 Secret（如果需要）
kubectl delete secret openhands-secrets
```

## 📝 常见问题

### Q1: Pod 一直处于 Pending 状态？

**A:** 可能是资源不足或 PVC 无法绑定。检查：

```bash
kubectl describe pod <pod-name>

# 如果是 PVC 问题
kubectl get pvc
kubectl describe pvc openhands-data
```

### Q2: 如何使用私有镜像仓库？

**A:** 创建 imagePullSecret：

```bash
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=your-username \
  --docker-password=your-password

helm install openhands . \
  --set imagePullSecrets[0].name=regcred
```

### Q3: Docker socket 挂载失败？

**A:** 检查主机路径是否正确：

```bash
# 如果使用 Kubernetes runtime，可能需要禁用 Docker socket
helm upgrade openhands . \
  --set dockerSocket.enabled=false \
  --set openhands.sandbox.runtime=kubernetes
```

### Q4: 如何配置自定义 LLM？

**A:** 修改 LLM 配置：

```bash
helm upgrade openhands . \
  --set openhands.llm.model=claude-3-opus-20240229 \
  --set openhands.llm.baseURL=https://api.anthropic.com/v1 \
  --set openhands.llm.apiKey=sk-ant-...
```

### Q5: 如何限制资源使用？

**A:** 设置资源限制：

```bash
helm upgrade openhands . \
  --set resources.requests.cpu=2 \
  --set resources.requests.memory=4Gi \
  --set resources.limits.cpu=8 \
  --set resources.limits.memory=16Gi
```

## 📚 更多资源

- [完整文档](./README.md)
- [配置参数参考](./values.yaml)
- [生产环境示例](./values-production-example.yaml)
- [开发环境示例](./values-dev-example.yaml)
- [OpenHands 官方文档](https://docs.openhands.dev)
- [OpenHands GitHub](https://github.com/OpenHands/OpenHands)

## 🆘 获取帮助

如果遇到问题：

1. 查看 [GitHub Issues](https://github.com/OpenHands/OpenHands/issues)
2. 加入 [社区讨论](https://github.com/OpenHands/OpenHands/blob/main/COMMUNITY.md)
3. 查看 [官方文档](https://docs.openhands.dev)
