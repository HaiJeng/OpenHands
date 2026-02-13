# OpenHands Helm 部署问题修复指南

## 问题分析

根据最新日志分析 (`/workspace/openhands.log`)，发现以下主要问题：

### 1. **Docker Socket 权限错误** (核心问题)
**错误**: `docker.errors.DockerException: Error fetching server API version: (Connection aborted., PermissionError(13, Permission denied))`

**根本原因**: 
- Docker socket (`/var/run/docker.sock`) 属于 `root:docker` 组，权限为 `srw-rw----`
- 默认 `values.yaml` 配置强制容器以非root用户 (UID 42420) 运行
- 用户42420不在docker组中，无法访问Docker socket
- `deployment.yaml` 第60行设置 `SANDBOX_USER_ID: "0"` 仅为sandbox容器设置，不影响主容器

**修复**: 
- **方案1（推荐）**: 使用 `values-dind-fixed.yaml` - 移除runAsUser限制，允许访问Docker socket
- **方案2（测试用）**: 使用 `values-root-unsafe.yaml` - 容器完全以root运行
- **方案3**: 修改宿主机Docker socket权限（需要在每个节点操作）

### 2. 密钥配置缺失
**错误**: `⚠️ OH_SECRET_KEY was not defined. Secrets will not be persisted between restarts.`

**原因**: 缺少必要的密钥配置。

**修复**: 
- 添加 `openhands.jwtSecret` 和 `openhands.secretKey`
- 使用 `openssl rand -base64 32` 生成强密钥

### 3. 网络连接超时
**错误**: `HTTP error on github API: ConnectError : [Errno -3] Temporary failure in name resolution`

**原因**: DNS 解析问题或网络连接超时。

**修复**: 
- 配置可靠的 DNS 服务器 (8.8.8.8, 8.8.4.4)
- 增加 API 调用超时时间

## 修复配置

### 快速修复（推荐）

使用提供的快速修复脚本：

```bash
cd /workspace/project/OpenHands/helm
./quick-fix.sh
```

该脚本会自动：
1. 检查依赖和当前部署状态
2. 获取配置信息
3. 生成安全密钥
4. 部署或升级 OpenHands
5. 验证部署状态

### 1. Docker 权限修复 (values-dind-fixed.yaml)

```yaml
# 移除用户限制（推荐）
# 允许容器以镜像默认用户运行，可以访问Docker socket
podSecurityContext:
  fsGroup: 42420
  # 不设置 runAsUser，让容器以镜像默认用户运行

securityContext:
  runAsNonRoot: false  # 允许以root运行（Docker访问需要）
  # runAsUser: 42420  # 注释掉这行

# 确保Docker socket已启用
dockerSocket:
  enabled: true
  hostPath: /var/run/docker.sock
```

### 2. 使用修复配置文件部署

```bash
# 使用修复配置部署
helm install openhands ./openhands \
  -f values.yaml \
  -f values-dind-fixed.yaml \
  --namespace openhands \
  --create-namespace \
  --set openhands.llm.apiKey="your-actual-api-key" \
  --set openhands.jwtSecret="$(openssl rand -base64 32)" \
  --set openhands.secretKey="$(openssl rand -base64 32)"
```

### 3. Root 模式配置 (values-root-unsafe.yaml)

仅用于测试/开发：

```bash
# ⚠️ 不安全，仅用于测试
helm install openhands ./openhands \
  -f values.yaml \
  -f values-root-unsafe.yaml \
  --namespace openhands \
  --create-namespace
```

### 4. 网络配置

在 `values-dind-fixed.yaml` 中已包含：

```yaml
network:
  dns:
    servers:
    - 8.8.8.8
    - 8.8.4.4
  timeouts:
    githubApi: 60
    gitlabApi: 60
    general: 120
```

## 部署步骤

### 1. 基础部署

```bash
# 添加 OpenHands Helm 仓库
helm repo add openhands https://helm.openhands.dev
helm repo update

# 基础部署（使用修复后的配置）
helm install openhands ./openhands \
  -f values.yaml \
  --namespace openhands \
  --create-namespace
```

### 2. 生产环境部署

```bash
# 生产环境部署（推荐）
helm install openhands ./openhands \
  -f values.yaml \
  -f values-production-fixed.yaml \
  --namespace openhands \
  --create-namespace \
  --set openhands.llm.apiKey="your-actual-api-key" \
  --set openhands.jwtSecret="$(openssl rand -base64 32)" \
  --set openhands.secretKey="$(openssl rand -base64 32)"
```

### 3. 验证部署

```bash
# 检查 Pod 状态
kubectl get pods -n openhands

# 检查服务状态
kubectl get svc -n openhands

# 查看日志
kubectl logs -f deployment/openhands -n openhands

# 检查 PVC 绑定
kubectl get pvc -n openhands
```

## 故障排除

### 1. Docker 连接问题

如果仍然遇到 Docker 连接错误：

```bash
# 检查 Docker socket 是否存在
kubectl exec -it deployment/openhands -n openhands -- ls -la /var/run/docker.sock

# 检查节点上的 Docker 服务
kubectl get nodes -o wide
ssh <node-ip> sudo systemctl status docker
```

### 2. 权限问题

如果遇到权限错误：

```bash
# 检查 ServiceAccount 权限
kubectl get serviceaccount -n openhands
kubectl get clusterrolebinding | grep openhands

# 检查安全上下文
kubectl describe pod <pod-name> -n openhands | grep -A 10 "Security Context"
```

### 3. 网络问题

如果遇到网络连接问题：

```bash
# 测试 DNS 解析
kubectl exec -it deployment/openhands -n openhands -- nslookup github.com

# 测试网络连接
kubectl exec -it deployment/openhands -n openhands -- curl -I https://api.github.com
```

## 性能优化

### 1. 资源限制

根据实际使用情况调整资源限制：

```yaml
resources:
  limits:
    cpu: 8
    memory: 16Gi
  requests:
    cpu: 4
    memory: 8Gi
```

### 2. 存储优化

使用高性能存储类：

```yaml
persistence:
  data:
    storageClass: "fast-ssd"
  workspace:
    storageClass: "fast-ssd"
```

### 3. 自动扩缩容

启用 HPA 以应对负载变化：

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
```

## 安全建议

### 1. 密钥管理

- 使用 Kubernetes Secrets 管理敏感信息
- 定期轮换密钥
- 使用外部密钥管理服务（如 Vault）

### 2. 网络安全

- 配置网络策略限制 Pod 间通信
- 使用 TLS 加密所有通信
- 配置 Ingress 安全头

### 3. 运行时安全

- 使用非 root 用户运行容器
- 限制容器能力
- 启用安全扫描

## 监控和日志

### 1. 监控指标

部署 Prometheus 监控：

```bash
# 添加 Prometheus 监控
helm install prometheus prometheus-community/kube-prometheus-stack
```

### 2. 日志收集

使用 EFK 堆栈收集日志：

```bash
# 部署 Elasticsearch, Fluentd, Kibana
helm install efk elastic/efk
```

## 升级和维护

### 1. 升级部署

```bash
# 拉取最新 chart
helm repo update

# 升级部署
helm upgrade openhands ./openhands \
  -f values.yaml \
  -f values-production-fixed.yaml
```

### 2. 备份数据

```bash
# 备份 PVC 数据
kubectl get pvc -n openhands -o jsonpath='{.items[*].metadata.name}' | \
  xargs -I {} kubectl exec -it deployment/openhands -n openhands -- \
  tar czf /tmp/backup-{}.tar.gz /workspace
```

## 支持

如果遇到问题：

1. 检查本指南的故障排除部分
2. 查看 OpenHands 官方文档
3. 提交 issue 到 OpenHands GitHub 仓库
4. 联系技术支持团队