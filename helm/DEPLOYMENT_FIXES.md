# OpenHands Helm 部署问题修复指南

## 问题分析

根据日志分析，发现以下主要问题：

### 1. Docker 连接错误
**错误**: `docker.errors.DockerException: Error while fetching server API version: ('Connection aborted.', FileNotFoundError(2, 'No such file or directory'))`

**原因**: OpenHands 无法访问 Docker socket，导致无法创建运行时容器。

**修复**: 
- 启用 Docker socket 挂载 (`dockerSocket.enabled: true`)
- 启用运行时特权模式 (`kubernetes.runtimePrivileged: true`)

### 2. 密钥配置缺失
**错误**: `⚠️ OH_SECRET_KEY was not defined. Secrets will not be persisted between restarts.`

**原因**: 缺少必要的密钥配置。

**修复**: 
- 添加 `OH_SECRET_KEY` 环境变量
- 配置强密钥用于生产环境

### 3. 网络连接超时
**错误**: `HTTP error on github API: ConnectError : [Errno -3] Temporary failure in name resolution`

**原因**: DNS 解析问题或网络连接超时。

**修复**: 
- 配置可靠的 DNS 服务器
- 增加 API 调用超时时间
- 配置代理（如需要）

## 修复配置

### 1. 基础修复 (values.yaml)

```yaml
# 启用 Docker socket
dockerSocket:
  enabled: true
  hostPath: /var/run/docker.sock

# 启用运行时特权模式
kubernetes:
  runtimePrivileged: true

# 添加密钥配置
openhands:
  jwtSecret: "your-secure-jwt-secret-here"
  secretKey: "your-secure-openhands-secret-key"
```

### 2. 网络配置

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

### 3. 生产环境推荐配置

使用提供的 `values-production-fixed.yaml` 文件，包含：
- 高可用性配置
- 资源限制优化
- 网络超时修复
- 安全加固

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