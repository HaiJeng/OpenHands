# OpenHands K8s Runtime 配置
# 纯 Kubernetes 部署，无需 Docker Socket

## 🚀 核心配置

```yaml
openhands:
  sandbox:
    runtime: kubernetes  # 使用原生 Kubernetes Pod
```

## 📦 使用方法

```bash
# 使用 Kubernetes runtime 配置部署
helm install openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-runtime.yaml \
  --namespace openhands \
  --create-namespace \
  --set openhands.llm.apiKey="your-api-key" \
  --set openhands.jwtSecret="$(openssl rand -base64 32)" \
  --set openhands.secretKey="$(openssl rand -base64 32)"
```

## ✅ 验证部署

```bash
# 检查 OpenHands Pod
kubectl get pods -n openhands

# 检查 Runtime Pod（由 OpenHands 创建）
kubectl get pods -A | grep runtime

# 查看日志
kubectl logs -f deployment/openhands -n openhands
```

## 🔍 关键差异对比

| 项目 | K8s Runtime | Docker Runtime |
|------|--------------|----------------|
| **配置** | `openhands.sandbox.runtime: kubernetes` | `openhands.sandbox.runtime: docker` |
| **Docker Socket** | ❌ 不需要 | ✅ 必需 |
| **权限要求** | 标准用户权限 | 需要 root 或 docker 组 |
| **沙箱隔离** | Kubernetes Pod | Docker 容器 |
| **资源管理** | 原生 K8s 资源限制 | 间接通过 Docker |
| **监控** | 可用 k8s 监控工具 | 需要 Docker 监控 |
| **安全性** | ✅ 更好（无特权访问） | ⚠️ 需要特权模式 |
| **适用场景** | ⭐ K8s 生产环境 | 本地开发、非K8s环境 |

## 📝 Runtime 工作流程

### Kubernetes Runtime 模式
```
┌─────────────────────────────────────┐
│  OpenHands Pod                   │
│  ┌───────────────────────────┐    │
│  │ Main Container (非Root)   │    │
│  │ User: 42420              │    │
│  │                            │    │
│  │ K8s API Client ──┐        │    │
│  └────────────────────┼─────┘    │
│                     │              │
└─────────────────────┼──────────────┘
                      │
                      │ K8s API 调用
                      ▼
          ┌───────────────────────────┐
          │ Runtime Pod (沙箱）        │
          │ 由 K8s 直接创建         │
          │ 完全隔离               │
          └───────────────────────────┘
```

### Docker Runtime 模式（对比）
```
┌──────────────────────────────────────┐
│  OpenHands Pod                    │
│  ┌───────────────────────────┐      │
│  │ Main Container (Root?)    │      │
│  │                            │      │
│  │ Docker Client ──┐          │      │
│  └──────────────────┼─────────┘      │
│                     │                  │
│  ┌──────────────────┼────────────┐   │
│  │ Docker Socket Mount│          │   │
│  │ /var/run/docker.sock│          │   │
│  └──────────────────┼────────────┘   │
│                     │                  │
└─────────────────────┼──────────────────┘
                      │ Docker API
                      ▼
          ┌───────────────────────────┐
          │ Docker Container (沙箱）  │
          │ 由 Docker daemon 创建     │
          └───────────────────────────┘
```

## ⚙️ Kubernetes Runtime 特定配置

### 1. Runtime Pod 命名空间
```yaml
kubernetes:
  namespace: default  # Runtime Pod 创建的命名空间
```

### 2. Runtime Pod 资源限制
```yaml
kubernetes:
  runtimeResources:
    cpu:
      request: "1"
      limit: "4"
    memory:
      request: "1Gi"
      limit: "4Gi"
```

### 3. Runtime Pod 特权模式
```yaml
kubernetes:
  runtimePrivileged: true  # 某些操作需要特权模式
```

### 4. Runtime PVC 配置
```yaml
kubernetes:
  pvc:
    storageSize: 10Gi
    storageClass: "rbd"  # 使用你的存储类
    accessMode: ReadWriteOnce
```

## 🔧 故障排除

### 问题1: Runtime Pod 无法启动
```bash
# 查看 Runtime Pod 状态
kubectl get pods -A | grep openhands

# 查看 Runtime Pod 详情
kubectl describe pod <runtime-pod-name> -n <namespace>

# 查看 Runtime Pod 日志
kubectl logs <runtime-pod-name> -n <namespace>
```

### 问题2: 权限错误
```bash
# 确认使用 Kubernetes runtime
kubectl get deployment openhands -n openhands -o yaml | grep RUNTIME

# 应该看到: RUNTIME: "kubernetes"
```

### 问题3: 存储问题
```bash
# 检查 PVC
kubectl get pvc -n openhands

# 检查 StorageClass
kubectl get storageclass
```

## 🎯 生产环境推荐配置

```yaml
openhands:
  sandbox:
    runtime: kubernetes
    maxIterations: 500
    maxBudget: 0.0
  
  llm:
    model: gpt-4o
    apiKey: "your-production-api-key"
    temperature: 0.0
  
  jwtSecret: "production-jwt-secret"
  secretKey: "production-secret-key"

kubernetes:
  namespace: openhands-runtimes
  pvc:
    storageSize: 20Gi
    storageClass: "fast-ssd"
  runtimeResources:
    cpu:
      request: "2"
      limit: "8"
    memory:
      request: "2Gi"
      limit: "8Gi"
  runtimePrivileged: true

# 关键：禁用 Docker Socket
dockerSocket:
  enabled: false

# 标准安全上下文
podSecurityContext:
  fsGroup: 42420
  runAsUser: 42420

securityContext:
  runAsNonRoot: true
  runAsUser: 42420
  privileged: false
  allowPrivilegeEscalation: false
```

## 📊 性能优化

### 1. 资源配置
```yaml
kubernetes:
  runtimeResources:
    cpu:
      request: "4"      # 根据负载调整
      limit: "16"
    memory:
      request: "4Gi"
      limit: "16Gi"
```

### 2. 存储优化
```yaml
kubernetes:
  pvc:
    storageClass: "ssd-storage"  # 使用高性能存储
    storageSize: "50Gi"
```

### 3. 节点亲和性
```yaml
kubernetes:
  runtimeNodeSelector:
    nodepool: workload  # 使用特定节点池
```

## 📖 参考文档

- [K8s Runtime 完整配置](./values-k8s-runtime.yaml)
- [通用部署指南](./openhands/DEPLOYMENT_GUIDE.md)
- [PVC 架构说明](./openhands/PVC_ARCHITECTURE.md)

## ⚠️ 重要提示

1. **不需要 Docker-in-Docker**: 使用 K8s runtime 时，OpenHands 直接创建 Pod，不需要 Docker
2. **更安全**: 不需要挂载 Docker socket，减少安全风险
3. **更好监控**: 可直接使用 Kubernetes 监控和日志工具
4. **原生集成**: 与 K8s API、Service、Ingress 等原生集成

## 🔄 从 Docker Runtime 迁移到 K8s Runtime

如果你当前使用 Docker runtime，迁移很简单：

1. **修改配置**:
   ```yaml
   openhands:
     sandbox:
       runtime: kubernetes  # 从 docker 改为 kubernetes
   ```

2. **禁用 Docker Socket**:
   ```yaml
   dockerSocket:
     enabled: false
   ```

3. **重新部署**:
   ```bash
   helm upgrade openhands ./openhands \
     -f ./openhands/values-k8s-runtime.yaml \
     --namespace openhands
   ```

4. **验证**:
   ```bash
   # 确认无 Docker socket 挂载
   kubectl describe deployment openhands -n openhands | grep -i docker
   
   # 确认 Runtime Pod 正常创建
   kubectl get pods -A | grep runtime
   ```

---
**版本**: 1.0  
**更新**: 2025-01-13  
**适用于**: Kubernetes 生产环境
