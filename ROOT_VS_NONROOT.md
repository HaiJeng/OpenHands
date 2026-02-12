# OpenHands Kubernetes 部署：Root 用户 vs 非 Root 用户对比

## 问题背景

OpenHands 的 `entrypoint.sh` 脚本原本要求以 root 用户运行，但 Kubernetes 安全最佳实践建议容器以非 root 用户运行。

## 方案对比

### 方案 A：以 Root 用户运行（不推荐）

#### 配置方式

修改 `values.yaml`：

```yaml
# Pod security context - 以 root 运行
podSecurityContext:
  runAsUser: 0      # root 用户
  runAsGroup: 0
  fsGroup: 0

# Container security context
securityContext:
  runAsNonRoot: false    # 允许以 root 运行
  runAsUser: 0
  privileged: false
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
```

#### 部署命令

```bash
helm install openhands ./openhands \
  --set podSecurityContext.runAsUser=0 \
  --set podSecurityContext.runAsGroup=0 \
  --set podSecurityContext.fsGroup=0 \
  --set securityContext.runAsNonRoot=false \
  --set securityContext.runAsUser=0 \
  --set openhands.llm.apiKey=your-key
```

#### ⚠️ 安全风险

| 风险项 | 严重程度 | 说明 |
|--------|---------|------|
| **容器逃逸** | 🔴 高 | 如果容器被攻破，攻击者直接获得 root 权限 |
| **主机入侵** | 🔴 高 | 有权限访问宿主机文件系统（如果配置了卷挂载） |
| **权限过大** | 🔴 高 | 容器内的进程拥有不必要的系统权限 |
| **合规问题** | 🟡 中 | 违反安全合规要求（如 CIS、PCI-DSS） |
| **集群安全** | 🟡 中 | 可能影响整个 Kubernetes 集群的安全 |

#### 优点

- ✅ **无需修改代码** - 可以直接使用原始 `entrypoint.sh`
- ✅ **快速部署** - 不需要等待镜像重新构建
- ✅ **兼容性好** - 所有功能都能正常工作

#### 缺点

- ❌ **严重安全风险** - 容器逃逸可能导致主机被完全控制
- ❌ **违反最佳实践** - 不符合 Kubernetes 和容器安全标准
- ❌ **审计问题** - 安全审计会标记为高风险配置
- ❌ **生产环境禁用** - 大多数生产环境禁止以 root 运行容器

---

### 方案 B：以非 Root 用户运行（推荐）✅

#### 当前配置（已修复）

`values.yaml` 中的默认配置：

```yaml
# Pod security context - 以非 root 运行
podSecurityContext:
  runAsUser: 42420    # 专用非 root 用户
  runAsGroup: 42420
  fsGroup: 42420

# Container security context
securityContext:
  runAsNonRoot: true   # 强制非 root
  runAsUser: 42420
  privileged: false
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
```

#### 已修复的问题

修改了 `containers/app/entrypoint.sh`：

```bash
# 删除了第 11-14 行的强制 root 检查
# if [ "$(id -u)" -ne 0 ]; then
#   echo "The OpenHands entrypoint.sh must run as root"
#   exit 1
# fi
```

#### ✅ 安全优势

| 优势项 | 说明 |
|--------|------|
| **最小权限** | 容器只拥有必要的权限 |
| **降低攻击面** | 即使容器被攻破，攻击者也只能获得普通用户权限 |
| **符合最佳实践** | 遵循 Kubernetes 和容器安全标准 |
| **合规友好** | 通过安全审计 |
| **生产可用** | 适合生产环境部署 |

#### 优点

- ✅ **安全性高** - 符合安全最佳实践
- ✅ **生产就绪** - 可以在生产环境使用
- ✅ **通过审计** - 满足大多数安全合规要求
- ✅ **最小权限** - 遵循最小权限原则

#### 缺点

- ❌ **需要重新构建镜像** - 必须包含修复后的 `entrypoint.sh`
- ❌ **部署时间** - 需要等待镜像构建（15-30 分钟）

---

## 快速决策指南

### 选择 Root 运行的场景

**仅在以下情况考虑：**

1. **开发/测试环境** - 临时的开发环境
2. **快速验证** - 需要快速验证功能
3. **隔离环境** - 完全隔离的测试集群
4. **时间紧迫** - 无法等待镜像重建

**示例配置：**

```yaml
# 仅用于开发/测试
podSecurityContext:
  runAsUser: 0

securityContext:
  runAsNonRoot: false
```

```bash
# 快速部署测试
helm install openhands-test ./openhands \
  --set podSecurityContext.runAsUser=0 \
  --set securityContext.runAsNonRoot=false \
  --set openhands.llm.apiKey=test-key
```

### 选择非 Root 运行的场景（强烈推荐）

**适用于所有情况，特别是：**

1. **生产环境** - 所有生产部署
2. **多租户环境** - 多个团队共享集群
3. **合规要求** - 需要通过安全审计
4. **长期运行** - 持续运行的服务
5. **互联网暴露** - 可从互联网访问的服务

**示例配置：**

```yaml
# 使用默认配置即可
podSecurityContext:
  runAsUser: 42420

securityContext:
  runAsNonRoot: true
```

```bash
# 推荐部署方式
helm install openhands ./openhands \
  --set openhands.llm.apiKey=your-key \
  --reuse-values
```

---

## 实际部署示例

### 场景 1：开发测试 - 临时使用 Root

```bash
# 1. 快速部署测试（使用 root）
helm install openhands-dev ./openhands \
  --set podSecurityContext.runAsUser=0 \
  --set podSecurityContext.fsGroup=0 \
  --set securityContext.runAsNonRoot=false \
  --set securityContext.runAsUser=0 \
  --set openhands.llm.apiKey=test-key \
  --set openhands.llm.model=gpt-4o

# 2. 测试完成后，使用非 root 重新部署
helm uninstall openhands-dev
# 等待新镜像构建完成...

# 3. 使用非 root 部署
helm install openhands-dev ./openhands \
  --set openhands.llm.apiKey=test-key \
  --set openhands.llm.model=gpt-4o
```

### 场景 2：生产环境 - 必须使用非 Root

```bash
# 1. 确保使用修复后的镜像
# （已经包含在 ghcr.io/openhands/openhands:latest 中）

# 2. 使用默认配置（非 root）
helm install openhands ./openhands \
  --set openhands.llm.apiKey=$LLM_API_KEY \
  --set openhands.llm.model=gpt-4o \
  --set persistence.data.size=20Gi \
  --set persistence.workspace.size=100Gi \
  --namespace production

# 3. 验证安全配置
kubectl get pod -n production -l app.kubernetes.io/name=openhands \
  -o jsonpath='{.items[0].spec.securityContext}' | jq .

# 4. 验证不以 root 运行
kubectl exec -n production <pod-name> -- id
# 应该输出：uid=42420(openhands) gid=42420(openhands) groups=42420(openhands)
```

---

## 安全最佳实践建议

### 1. 使用 Pod Security Standards

Kubernetes 提供了 Pod Security Standards：

```yaml
# 启用 Pod Security Admission
kubectl label namespace openhands \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted
```

### 2. 配置安全上下文

```yaml
# 推荐的安全配置
podSecurityContext:
  runAsUser: 42420
  runAsGroup: 42420
  fsGroup: 42420
  seccompProfile:
    type: RuntimeDefault

securityContext:
  runAsNonRoot: true
  runAsUser: 42420
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true  # 可选，提高安全性
```

### 3. 使用 PSP / OPA Gatekeeper

```yaml
# Pod Security Policy（Kubernetes < 1.25）
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: openhands-restricted
spec:
  privileged: false
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
  supplementalGroups:
    rule: 'RunAsAny'
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
```

### 4. 安全扫描

```bash
# 使用 Trivy 扫描镜像
trivy image ghcr.io/openhands/openhands:latest

# 使用 kube-bench 扫描集群
kubectl run kube-bench --image=aquasec/kube-bench:latest --rm --restart=Never
```

---

## 迁移路径

### 从 Root 迁移到非 Root

```bash
# 1. 备份当前配置
helm get values openhands > old-values.yaml

# 2. 卸载当前部署
helm uninstall openhands

# 3. 确保使用修复后的镜像
# (GitHub Actions 已构建)

# 4. 使用非 root 配置重新部署
helm install openhands ./openhands \
  -f old-values.yaml \
  --set podSecurityContext.runAsUser=42420 \
  --set securityContext.runAsNonRoot=true

# 5. 验证
kubectl get pods -l app.kubernetes.io/name=openhands
kubectl logs -l app.kubernetes.io/name=openhands --tail=20
```

---

## 常见问题

### Q1: 为什么不能一直使用 root？

**A**: 
- **安全风险** - 容器逃逸会导致主机被完全控制
- **合规要求** - 违反 CIS、PCI-DSS 等安全标准
- **生产环境** - 大多数企业禁止生产环境使用 root
- **集群安全** - 可能影响整个 Kubernetes 集群

### Q2: 非 root 用户会影响功能吗？

**A**: 
- ✅ **不会** - OpenHands 的所有功能都可以正常工作
- ✅ **性能相同** - 没有性能差异
- ✅ **兼容性好** - 与所有 Kubernetes 功能兼容

### Q3: 如何验证容器不是以 root 运行？

**A**:
```bash
# 方法 1：查看进程用户
kubectl exec <pod-name> -- id
# 预期：uid=42420(openhands) gid=42420(openhands)

# 方法 2：查看安全上下文
kubectl describe pod <pod-name> | grep -A 5 "Security Context"

# 方法 3：检查安全策略
kubectl get psp -o yaml | grep -A 10 openhands
```

### Q4: 可以自定义 UID 吗？

**A**: 可以，但不推荐

```yaml
# 可以自定义，但需要确保 UID > 1000
podSecurityContext:
  runAsUser: 10001  # 自定义 UID
```

---

## 推荐配置文件

### 开发环境（values-dev.yaml）

```yaml
# 开发环境：可以使用 root，但不推荐
podSecurityContext:
  runAsUser: 42420  # 仍然推荐非 root

securityContext:
  runAsNonRoot: true

openhands:
  llm:
    model: gpt-4o-mini  # 使用更便宜的模型
```

### 生产环境（values-production.yaml）

```yaml
# 生产环境：必须使用非 root
podSecurityContext:
  runAsUser: 42420
  runAsGroup: 42420
  fsGroup: 42420
  seccompProfile:
    type: RuntimeDefault

securityContext:
  runAsNonRoot: true
  runAsUser: 42420
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: false  # 需要写入，所以设为 false

resources:
  requests:
    cpu: 2
    memory: 4Gi
  limits:
    cpu: 8
    memory: 16Gi

persistence:
  data:
    size: 20Gi
    storageClass: fast-ssd
  workspace:
    size: 100Gi
    storageClass: fast-ssd
```

---

## 总结

| 特性 | Root 用户 | 非 Root 用户 |
|------|-----------|-------------|
| **安全性** | ❌ 低 | ✅ 高 |
| **生产就绪** | ❌ 否 | ✅ 是 |
| **合规性** | ❌ 不通过 | ✅ 通过 |
| **部署速度** | ✅ 快 | ⚠️ 需要重建镜像 |
| **功能完整性** | ✅ 完整 | ✅ 完整 |
| **推荐使用** | ❌ 仅测试 | ✅ 所有环境 |

**最终建议：**
- 🔴 **不要**在生产环境使用 root
- 🟡 **仅在**临时测试环境使用 root
- ✅ **强烈推荐**使用非 root 用户（方案 B）
