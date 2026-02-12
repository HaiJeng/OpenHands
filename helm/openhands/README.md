# OpenHands Helm Chart

OpenHands 是一个 AI 驱动的软件工程师，可以使用 Helm 在 Kubernetes 集群中部署。

## 功能特性

- 完整的 OpenHands 应用部署
- 可自定义所有镜像的 tag
- 持久化存储支持
- ConfigMap 和 Secret 配置管理
- 水平自动扩缩容 (HPA)
- Ingress 支持
- 资源限制和请求配置

## 前置要求

- Kubernetes 1.19+
- Helm 3.0+
- PV provisioner 支持（用于持久化存储）
- Docker socket 访问（如果使用 Docker runtime）

## 安装

### 添加 Helm 仓库（如果有）

```bash
helm repo add openhands https://openhands.dev/helm-charts
helm repo update
```

### 从本地安装

```bash
# 克隆仓库
git clone https://github.com/OpenHands/OpenHands.git
cd OpenHands/helm/openhands

# 安装 chart
helm install openhands ./openhands
```

### 快速安装（使用默认配置）

```bash
helm install openhands ./openhands \
  --set openhands.llm.apiKey=your-api-key \
  --set openhands.llm.model=gpt-4o
```

## 配置

### 自定义镜像 Tag

这是最重要的配置选项，您可以指定所有使用的镜像 tag：

```bash
helm install openhands ./openhands \
  --set image.repository=docker.openhands.dev/openhands/openhands \
  --set image.tag=v0.0.1 \
  --set image.runtime.repository=ghcr.io/openhands/runtime \
  --set image.runtime.tag=v0.0.1-runtime \
  --set image.agentServer.repository=ghcr.io/openhands/agent-server \
  --set image.agentServer.tag=v0.0.1-agent \
  --set image.uv.repository=ghcr.io/astral-sh/uv \
  --set image.uv.tag=latest
```

或者在 values.yaml 文件中配置：

```yaml
image:
  repository: docker.openhands.dev/openhands/openhands
  tag: v0.0.1
  runtime:
    repository: ghcr.io/openhands/runtime
    tag: v0.0.1-runtime
  agentServer:
    repository: ghcr.io/openhands/agent-server
    tag: v0.0.1-agent
  uv:
    repository: ghcr.io/astral-sh/uv
    tag: latest
```

### LLM 配置

OpenHands 需要 LLM API 密钥才能工作：

```bash
helm install openhands ./openhands \
  --set openhands.llm.apiKey=sk-... \
  --set openhands.llm.model=gpt-4o \
  --set openhands.llm.baseURL=https://api.openai.com/v1
```

使用自定义配置文件：

```bash
helm install openhands ./openhands -f custom-values.yaml
```

### 持久化存储

默认启用 10Gi 的持久化存储。自定义存储配置：

```bash
helm install openhands ./openhands \
  --set persistence.size=20Gi \
  --set persistence.storageClass=fast-ssd \
  --set persistence.accessMode=ReadWriteMany
```

使用现有的 PVC：

```bash
helm install openhands ./openhands \
  --set persistence.enabled=true \
  --set persistence.existingClaim=openhands-data
```

### Ingress 配置

启用 Ingress 用于外部访问：

```bash
helm install openhands ./openhands \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.hosts[0].host=openhands.example.com \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix
```

启用 TLS：

```bash
helm install openhands ./openhands \
  --set ingress.enabled=true \
  --set ingress.tls[0].secretName=openhands-tls \
  --set ingress.tls[0].hosts[0]=openhands.example.com
```

### 资源配置

根据需要调整 CPU 和内存资源：

```bash
helm install openhands ./openhands \
  --set resources.requests.cpu=2 \
  --set resources.requests.memory=4Gi \
  --set resources.limits.cpu=8 \
  --set resources.limits.memory=16Gi
```

### Docker Socket 配置

如果使用 Docker runtime，需要挂载 Docker socket：

```bash
helm install openhands ./openhands \
  --set dockerSocket.enabled=true \
  --set dockerSocket.hostPath=/var/run/docker.sock
```

**安全警告**：挂载 Docker socket 可能会带来安全风险。在生产环境中，考虑使用远程 runtime 或 podman。

## 高级配置

### 使用 Secret 管理敏感信息

创建 Secret：

```bash
kubectl create secret generic openhands-secrets \
  --from-literal=llmApiKey=sk-... \
  --from-literal=jwtSecret=your-jwt-secret
```

引用 Secret：

```bash
helm install openhands ./openhands \
  --set secret.enabled=true \
  --set secret.existingSecret=openhands-secrets
```

### 使用 ConfigMap 配置

创建包含 TOML 配置的 ConfigMap：

```bash
kubectl create configmap openhands-config \
  --from-file=config.toml=/path/to/config.toml
```

引用 ConfigMap：

```bash
helm install openhands ./openhands \
  --set config.enabled=true \
  --set config.existingConfigmap=openhands-config
```

### 水平自动扩缩容

启用 HPA：

```bash
helm install openhands ./openhands \
  --set autoscaling.enabled=true \
  --set autoscaling.minReplicas=2 \
  --set autoscaling.maxReplicas=5 \
  --set autoscaling.targetCPUUtilizationPercentage=70
```

### 节点选择器和亲和性

部署到特定节点：

```bash
helm install openhands ./openhands \
  --set nodeSelector."node\.kubernetes\.io/instance-type"=large \
  --set tolerations[0].key=node.kubernetes.io/not-ready \
  --set tolerations[0].operator=Exists \
  --set tolerations[0].effect=NoExecute
```

## 配置参数

### 全局参数

| 参数 | 描述 | 默认值 |
|------|------|--------|
| `global.imagePullSecrets` | 全局镜像拉取密钥 | `[]` |

### 镜像参数（重点）

| 参数 | 描述 | 默认值 |
|------|------|--------|
| `image.repository` | 主应用镜像仓库 | `docker.openhands.dev/openhands/openhands` |
| `image.tag` | 主应用镜像 tag | `latest` |
| `image.runtime.repository` | Runtime 镜像仓库 | `ghcr.io/openhands/runtime` |
| `image.runtime.tag` | Runtime 镜像 tag | `latest` |
| `image.agentServer.repository` | Agent server 镜像仓库 | `ghcr.io/openhands/agent-server` |
| `image.agentServer.tag` | Agent server 镜像 tag | `latest` |
| `image.uv.repository` | UV 镜像仓库 | `ghcr.io/astral-sh/uv` |
| `image.uv.tag` | UV 镜像 tag | `latest` |

### OpenHands 配置

| 参数 | 描述 | 默认值 |
|------|------|--------|
| `openhands.llm.model` | LLM 模型 | `gpt-4o` |
| `openhands.llm.apiKey` | LLM API 密钥 | `""` |
| `openhands.llm.baseURL` | LLM API 基础 URL | `""` |
| `openhands.llm.temperature` | LLM 温度 | `0.0` |
| `openhands.workspace.base` | 工作区基础路径 | `/opt/workspace_base` |
| `openhands.sandbox.runtime` | Sandbox runtime 类型 | `docker` |
| `openhands.sandbox.maxIterations` | 最大迭代次数 | `500` |
| `openhands.security.enableAnalyzer` | 启用安全分析器 | `true` |
| `openhands.browser.enabled` | 启用浏览器 | `true` |
| `openhands.jwtSecret` | JWT 密钥 | `""` |

### Kubernetes 配置

| 参数 | 描述 | 默认值 |
|------|------|--------|
| `replicaCount` | 副本数 | `1` |
| `persistence.enabled` | 启用持久化 | `true` |
| `persistence.size` | 存储大小 | `10Gi` |
| `persistence.storageClass` | 存储类 | `""` |
| `service.type` | Service 类型 | `ClusterIP` |
| `service.port` | Service 端口 | `3000` |
| `ingress.enabled` | 启用 Ingress | `false` |
| `ingress.className` | Ingress 类名 | `""` |
| `resources.requests.cpu` | CPU 请求 | `1` |
| `resources.requests.memory` | 内存请求 | `2Gi` |
| `resources.limits.cpu` | CPU 限制 | `4` |
| `resources.limits.memory` | 内存限制 | `8Gi` |

更多配置选项请查看 `values.yaml` 文件。

## 升级

```bash
helm upgrade openhands ./openhands
```

使用自定义 values 升级：

```bash
helm upgrade openhands ./openhands -f custom-values.yaml
```

回滚到之前的版本：

```bash
helm rollback openhands
```

## 卸载

```bash
helm uninstall openhands
```

删除持久化卷（可选）：

```bash
kubectl delete pvc openhands-data
```

## 故障排查

### 查看 Pod 状态

```bash
kubectl get pods -l app.kubernetes.io/name=openhands
```

### 查看日志

```bash
kubectl logs -l app.kubernetes.io/name=openhands --tail=100 -f
```

### 进入 Pod 调试

```bash
kubectl exec -it <pod-name> -- /bin/bash
```

### 检查事件

```bash
kubectl get events --sort-by='.lastTimestamp'
```

## 生产环境建议

1. **使用 Secret 管理敏感信息**：不要在命令行或 values.yaml 中明文存储 API 密钥
2. **启用持久化存储**：确保数据不会丢失
3. **配置资源限制**：防止 Pod 消耗过多资源
4. **使用固定镜像 tag**：不要使用 `latest` tag
5. **启用 TLS**：通过 Ingress 配置 HTTPS
6. **配置备份**：定期备份持久化数据
7. **监控和告警**：设置 Prometheus 监控和告警
8. **使用 RBAC**：限制 ServiceAccount 权限

## 示例配置文件

### 开发环境

```yaml
# dev-values.yaml
image:
  tag: dev

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2
    memory: 4Gi

persistence:
  size: 5Gi

openhands:
  llm:
    model: gpt-4o-mini
```

### 生产环境

```yaml
# prod-values.yaml
image:
  tag: v1.0.0

replicaCount: 3

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

resources:
  requests:
    cpu: 2
    memory: 4Gi
  limits:
    cpu: 8
    memory: 16Gi

persistence:
  size: 100Gi
  storageClass: fast-ssd

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: openhands.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: openhands-tls
      hosts:
        - openhands.example.com
```

部署：

```bash
helm install openhands ./openhands -f prod-values.yaml
```

## 许可证

Apache-2.0

## 支持

- GitHub Issues: https://github.com/OpenHands/OpenHands/issues
- 文档: https://docs.openhands.dev
- 社区: https://github.com/OpenHands/OpenHands/blob/main/COMMUNITY.md
