# OpenHands Kubernetes Runtime 部署

## 🎯 部署方式对比

| 方式 | 文件 | 复杂度 | 推荐场景 |
|------|------|--------|------------|
| ⭐ **生产部署** | [values-k8s-production.yaml](./openhands/values-k8s-production.yaml) | 中 | 生产环境、优化配置 |
| 🔧 **自定义部署** | [values.yaml](./openhands/values.yaml) + [my-values.yaml](/workspace/my-values.yaml) | 高 | 完全自定义配置 |
| 📚 **基础部署** | [values.yaml](./openhands/values.yaml) | 低 | 测试、开发环境 |

## 🚀 快速开始

### 步骤 1：设置变量

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

### 步骤 2：选择部署方式

#### ⭐ 方式 1：生产部署（推荐）

```bash
cd /workspace/project/OpenHands/helm

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

**特点**：
- ✅ Kubernetes runtime（无Docker socket）
- ✅ 使用您的 Harbor 仓库 (harbor.inspur.local)
- ✅ 优化的资源配置（CPU: 500m-2, 内存: 1Gi-2Gi）
- ✅ NodePort 服务配置
- ✅ 生产就绪

#### 🔧 方式 2：自定义部署

```bash
cd /workspace/project/OpenHands/helm

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

**特点**：
- ✅ 合并您的自定义配置
- ✅ 覆盖生产配置
- ✅ 灵活调整

### 步骤 3：验证部署

```bash
# 检查 Pod
kubectl get pods -n $NAMESPACE

# 检查 Service
kubectl get svc -n $NAMESPACE

# 查看日志
kubectl logs -f deployment/openhands -n $NAMESPACE

# 等待就绪
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=openhands \
  -n $NAMESPACE --timeout=300s
```

### 步骤 4：访问 OpenHands

#### NodePort（推荐）

```bash
# 获取访问地址
NODE_PORT=$(kubectl get svc openhands -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')

echo "访问地址: http://$NODE_IP:$NODE_PORT"
```

#### Port Forward

```bash
kubectl port-forward svc/openhands 3000:3000 -n $NAMESPACE

# 访问: http://localhost:3000
```

## 📋 配置文件说明

### 核心配置

| 文件 | 说明 |
|------|------|
| [values.yaml](./openhands/values.yaml) | 基础配置 |
| [values-k8s-production.yaml](./openhands/values-k8s-production.yaml) | Kubernetes runtime 生产配置 |
| [my-values.yaml](/workspace/my-values.yaml) | 您的自定义配置 |

### 关键配置项

```yaml
# ✅ Kubernetes Runtime（不使用 Docker socket）
openhands:
  sandbox:
    runtime: kubernetes

# ❌ 禁用 Docker Socket
dockerSocket:
  enabled: false

# 资源配置
resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2
    memory: 2Gi

# 服务配置
service:
  type: NodePort
  port: 3000
  sessionAffinity: ClientIP
```

## 📚 文档导航

### 快速开始
- **[QUICKSTART.md](./QUICKSTART.md)** - 快速开始指南

### 完整指南
- **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)** - 完整部署指南
  - 部署前检查
  - 分步部署说明
  - 故障排除
  - Ingress/TLS 配置

### Kubernetes Runtime
- **[K8S_RUNTIME_GUIDE.md](./K8S_RUNTIME_GUIDE.md)** - Kubernetes runtime 深入指南
  - 工作原理
  - 配置说明
  - 与 Docker runtime 对比

### 问题说明
- **[CORRECTION.md](./CORRECTION.md)** - 重要更正说明
  - 为什么不需要 Docker socket
  - Kubernetes runtime 的优势

### 更新日志
- **[DEPLOYMENT_FIXES.md](./DEPLOYMENT_FIXES.md)** - 部署问题修复记录

## 🔍 验证清单

### 部署前

- [ ] Kubernetes 集群正常
- [ ] Helm 已安装
- [ ] StorageClass 可用
- [ ] 镜像仓库可访问（harbor.inspur.local）
- [ ] LLM API Key 已设置
- [ ] JWT_SECRET 和 SECRET_KEY 已生成
- [ ] 资源配置合理（CPU、内存）

### 部署后

- [ ] OpenHands Pod 状态为 Running
- [ ] 日志无错误信息
- [ ] Service 正常创建
- [ ] PVC 绑定成功
- [ ] 可通过 NodePort 访问
- [ ] Runtime Pod 正常创建（当创建对话时）

## 🐛 故障排除

### Pod 无法启动

```bash
# 查看 Pod 详情
kubectl describe pod <pod-name> -n $NAMESPACE

# 查看日志
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

### 无法访问

```bash
# 检查 Service
kubectl get svc -n $NAMESPACE

# 检查 Endpoint
kubectl get endpoints openhands -n $NAMESPACE

# 测试内部访问
kubectl exec -it <pod-name> -n $NAMESPACE -- curl http://openhands:3000
```

## 🔄 升级部署

```bash
cd /workspace/project/OpenHands/helm

helm upgrade openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace $NAMESPACE \
  --reuse-values \
  --wait
```

## 🗑️ 卸载部署

```bash
# 删除部署
helm uninstall openhands --namespace $NAMESPACE

# 删除命名空间（可选）
kubectl delete namespace $NAMESPACE

# 删除 PVC（可选）
kubectl delete pvc -n $NAMESPACE
```

## 🎯 核心要点

### ✅ 正确配置

```yaml
openhands:
  sandbox:
    runtime: kubernetes  # ✅ 使用 Kubernetes runtime

dockerSocket:
  enabled: false  # ✅ 不需要 Docker socket
```

### ❌ 错误配置

```yaml
openhands:
  sandbox:
    runtime: docker  # ❌ K8s 环境不推荐

dockerSocket:
  enabled: true  # ❌ 导致权限问题
```

## 📊 架构说明

### Kubernetes Runtime 工作流

```
┌─────────────────────────────────────┐
│  OpenHands Pod (主应用)         │
│  ┌───────────────────────────┐    │
│  │ Main Container           │    │
│  │ - User: 42420 (非root)  │    │
│  │ - 无 Docker Socket       │    │
│  │                          │    │
│  │ Kubernetes API Client  │    │
│  └───────────────────────────┘    │
└─────────────────────────────────────┘
               │
               │ Kubernetes API 调用
               ▼
   ┌───────────────────────────────────┐
   │  Runtime Pod (沙箱)            │
   │  ┌───────────────────────────┐    │
   │  │ Sandboxed Environment     │    │
   │  │ - 隔离的用户代码执行    │    │
   │  │ - 受限的资源            │    │
   │  │ - 由 K8s 直接管理       │    │
   │  └───────────────────────────┘    │
   └───────────────────────────────────┘
```

### 与 Docker Runtime 对比

| 特性 | Kubernetes Runtime ✅ | Docker Runtime ❌ |
|------|---------------------|-----------------|
| Docker Socket | 不需要 | 必需 |
| 安全性 | 高（无特权） | 低（需特权） |
| K8s 集成 | 原生 | 间接 |
| 资源管理 | K8s 直接管理 | 通过 Docker |
| 监控 | 标准 K8s 工具 | 需要 Docker 监控 |
| 复杂度 | 简单 | 复杂（需 DinD） |

## 💡 最佳实践

### 生产环境

1. **使用 Kubernetes runtime** ✅
2. **配置 Ingress + TLS** ✅
3. **启用 HPA 自动扩缩容** ✅
4. **配置资源限制** ✅
5. **使用持久化存储** ✅
6. **配置监控告警** ✅

### 开发/测试环境

1. **使用 NodePort 访问** ✅
2. **降低资源配置** ✅
3. **禁用持久化存储（可选）** ✅

## 📞 获取帮助

### 查看日志

```bash
# OpenHands 主应用日志
kubectl logs -f deployment/openhands -n $NAMESPACE

# Runtime Pod 日志
kubectl logs -f -l app.kubernetes.io/name=openhands-runtime -A
```

### 检查配置

```bash
# 查看部署配置
kubectl get deployment openhands -n $NAMESPACE -o yaml

# 查看 runtime 配置
kubectl get deployment openhands -n $NAMESPACE -o yaml | grep -A 5 RUNTIME
```

### 获取 Pod 信息

```bash
# 获取 Pod 名称
POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')

# 进入 Pod
kubectl exec -it $POD -n $NAMESPACE -- bash

# 查看 Pod 详情
kubectl describe pod $POD -n $NAMESPACE
```

## 🎉 完成！

部署成功后，您就可以：

- ✅ 通过 Web UI 使用 OpenHands
- ✅ 创建 AI 辅助的编程任务
- ✅ 浏览和编辑代码
- ✅ 执行命令和脚本
- ✅ 集成 GitHub/GitLab 等服务

---

**需要帮助？**

- 查看完整指南：[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
- 查看快速开始：[QUICKSTART.md](./QUICKSTART.md)
- 查看日志：`kubectl logs -f deployment/openhands -n $NAMESPACE`

**祝您使用愉快！** 🚀
