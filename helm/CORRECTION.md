# ⚠️ 重要更正：Kubernetes Runtime 正确配置

## ❌ 错误的修复方向

之前提供的 `values-dind-fixed.yaml` 是**错误**的方向，它试图修复Docker socket访问问题。

但问题根源是：**为什么要用Docker？**

## ✅ 正确的解决方案

### 您说得对：使用Kubernetes Runtime

在Kubernetes环境中部署OpenHands时，应该使用**原生Kubernetes runtime**，而不是Docker-in-Docker。

### 为什么不需要Docker Socket？

1. **Docker Runtime模式** (需要Docker socket):
   ```
   OpenHands Pod → Docker Socket → Docker Daemon → 沙箱容器
   ```
   - ❌ 需要挂载Docker socket (不安全）
   - ❌ 需要特权模式
   - ❌ 需要Docker-in-Docker
   - ❌ 破坏Kubernetes隔离

2. **Kubernetes Runtime模式** (推荐):
   ```
   OpenHands Pod → Kubernetes API → Runtime Pod (沙箱）
   ```
   - ✅ 不需要Docker socket
   - ✅ 使用原生Kubernetes Pod
   - ✅ 更好的资源隔离
   - ✅ 更安全的权限模型
   - ✅ 原生Kubernetes监控

## 🚀 正确的修复配置

### 1. 使用 `values-k8s-runtime.yaml`

```bash
cd /workspace/project/OpenHands/helm

helm install openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-runtime.yaml \
  --namespace openhands \
  --create-namespace \
  --set openhands.llm.apiKey="your-api-key" \
  --set openhands.jwtSecret="$(openssl rand -base64 32)" \
  --set openhands.secretKey="$(openssl rand -base64 32)"
```

### 2. 关键配置

```yaml
openhands:
  sandbox:
    runtime: kubernetes  # ✅ 使用Kubernetes runtime

kubernetes:
  namespace: default
  runtimePrivileged: true  # ✅ Runtime Pod特权模式
  runtimeResources:
    cpu:
      request: "1"
      limit: "4"
    memory:
      request: "1Gi"
      limit: "4Gi"

# ❌ 禁用Docker socket
dockerSocket:
  enabled: false

# ✅ 标准权限（不需要root）
podSecurityContext:
  fsGroup: 42420
  runAsUser: 42420

securityContext:
  runAsNonRoot: true
  runAsUser: 42420
  privileged: false
```

## 📋 文件对比

| 文件 | Runtime | Docker Socket | 用途 |
|------|----------|---------------|--------|
| `values-dind-fixed.yaml` | docker | ✅ 需要 | ❌ **错误方向** |
| `values-k8s-runtime.yaml` | kubernetes | ❌ 不需要 | ✅ **正确** |
| `values-root-unsafe.yaml` | docker | ✅ 需要 | ⚠️ 仅测试 |

## 🔍 问题诊断

### 检查当前Runtime配置

```bash
# 检查values.yaml中的runtime设置
grep -A 2 "sandbox:" /workspace/project/OpenHands/helm/openhands/values.yaml

# 应该看到:
# runtime: kubernetes  (不是 docker）
```

### 如果设置为docker，为什么报错？

```
docker.errors.DockerException: Permission denied on /var/run/docker.sock
```

**原因**: 
- K8s Pod以非root用户(42420)运行
- 无法访问 `/var/run/docker.sock` (属于root:docker组)
- 这是**预期的安全行为**

**错误的修复**: 修改权限让用户42420访问docker socket (不安全！)

**正确的修复**: 切换到Kubernetes runtime，不需要docker socket！

## 🎯 推荐方案总结

### 方案1: Kubernetes Runtime (⭐ 强烈推荐)

```bash
# 使用纯Kubernetes配置
helm install openhands ./openhands \
  -f ./openhands/values-k8s-runtime.yaml \
  --namespace openhands --create-namespace
```

**优势**:
- ✅ 安全：不需要Docker socket
- ✅ 原生K8s集成
- ✅ 更好的资源管理
- ✅ 更容易监控
- ✅ 符合K8s最佳实践

### 方案2: Docker-in-Docker (仅特殊场景)

如果必须使用Docker runtime（不推荐），需要：

1. **部署Docker-in-Docker**:
   ```yaml
   # 部署独立的Docker服务
   apiVersion: v1
   kind: DaemonSet
   metadata:
     name: dind
   spec:
       template:
         spec:
           containers:
           - name: dind
             image: docker:dind
             privileged: true
             volumeMounts:
             - name: docker-graph
               mountPath: /var/lib/docker
           volumes:
           - name: docker-graph
             emptyDir: {}
   ```

2. **配置OpenHands使用远程Docker**:
   ```yaml
   openhands:
     sandbox:
       runtime: docker
       # 配置DOCKER_HOST指向DinD服务
   extraEnv:
   - name: DOCKER_HOST
     value: tcp://dind-service:2375
   ```

**劣势**:
- ❌ 需要额外部署DinD
- ❌ 复杂性增加
- ❌ 安全风险更高
- ❌ 资源开销大

## 📖 完整文档

- **[K8S_RUNTIME_GUIDE.md](./K8S_RUNTIME_GUIDE.md)** - Kubernetes Runtime完整指南
- **[values-k8s-runtime.yaml](./openhands/values-k8s-runtime.yaml)** - 推荐配置文件

## 🔄 迁移步骤

如果您当前使用Docker runtime，迁移到Kubernetes runtime：

1. **备份当前配置**:
   ```bash
   helm get values openhands -n openhands > current-values.yaml
   ```

2. **切换runtime配置**:
   ```yaml
   openhands:
     sandbox:
       runtime: kubernetes  # 从 docker 改为 kubernetes
   
   dockerSocket:
     enabled: false  # 禁用
   ```

3. **升级部署**:
   ```bash
   helm upgrade openhands ./openhands \
     -f ./openhands/values.yaml \
     -f ./openhands/values-k8s-runtime.yaml \
     --namespace openhands
   ```

4. **验证**:
   ```bash
   # 确认无Docker socket
   kubectl describe deployment openhands -n openhands | grep -i docker
   
   # 确认Runtime Pod正常创建
   kubectl get pods -A | grep openhands
   ```

## ✅ 总结

**您的观点完全正确**：
1. Kubernetes部署应该使用Kubernetes runtime
2. 不需要Docker socket
3. 不需要Docker-in-Docker（除非有特殊需求）

**正确文件**: `values-k8s-runtime.yaml`  
**错误文件**: `values-dind-fixed.yaml` (仅用于理解问题，不应使用）

**推荐**: 删除 `values-dind-fixed.yaml`，使用 `values-k8s-runtime.yaml`