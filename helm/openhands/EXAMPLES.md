# OpenHands Helm Chart 使用示例

本文档展示了各种常见场景的配置示例。

## 📋 场景目录

1. [本地开发环境](#场景1本地开发环境)
2. [测试环境](#场景2测试环境)
3. [生产环境](#场景3生产环境)
4. [自定义镜像版本](#场景4自定义镜像版本重点)
5. [使用不同的 LLM Provider](#场景5使用不同的-llm-provider)
6. [GPU 支持](#场景6gpu-支持)
7. [多租户部署](#场景7多租户部署)
8. [离线/私有部署](#场景8离线私有部署)

---

## 场景 1：本地开发环境

### 需求

- 最小资源使用
- 使用便宜的 LLM 模型
- Port forward 访问
- 小存储空间

### 安装命令

```bash
# 使用 Makefile
make install-dev API_KEY=sk-your-api-key

# 或使用 Helm
helm install openhands-dev . \
  -f values-dev-example.yaml \
  --set openhands.llm.apiKey=sk-your-api-key \
  --namespace development
```

### 自定义 values-dev.yaml

```yaml
# values-dev-local.yaml
image:
  tag: latest

replicaCount: 1

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2
    memory: 4Gi

persistence:
  enabled: true
  size: 5Gi

openhands:
  llm:
    model: gpt-4o-mini  # 更便宜的模型
    temperature: 0.0
  
  workspace:
    base: /opt/workspace_base
    initGit: true

# 禁用 ingress，使用 port-forward
ingress:
  enabled: false

autoscaling:
  enabled: false

service:
  type: ClusterIP
  port: 3000
```

### 访问应用

```bash
# Port forward
kubectl port-forward -n development svc/openhands-dev 3000:3000

# 访问
open http://localhost:3000
```

---

## 场景 2：测试环境

### 需求

- 模拟生产配置
- 使用固定版本
- 基本监控
- 中等资源

### 安装命令

```bash
helm install openhands-test . \
  -f values-dev-example.yaml \
  --set image.tag=v0.0.1 \
  --set image.runtime.tag=v0.0.1-runtime \
  --set image.agentServer.tag=v0.0.1-agent \
  --set openhands.llm.apiKey=sk-your-test-key \
  --namespace testing
```

### 自定义 values-test.yaml

```yaml
# values-test.yaml
image:
  repository: docker.openhands.dev/openhands/openhands
  tag: v0.0.1  # 固定版本
  pullPolicy: IfNotPresent

  runtime:
    repository: ghcr.io/openhands/runtime
    tag: v0.0.1-runtime
    pullPolicy: IfNotPresent

  agentServer:
    repository: ghcr.io/openhands/agent-server
    tag: v0.0.1-agent
    pullPolicy: IfNotPresent

replicaCount: 2

resources:
  requests:
    cpu: 1
    memory: 2Gi
  limits:
    cpu: 4
    memory: 8Gi

persistence:
  enabled: true
  size: 20Gi
  storageClass: standard

service:
  type: LoadBalancer

ingress:
  enabled: false

openhands:
  llm:
    model: gpt-4o
    temperature: 0.0
```

---

## 场景 3：生产环境

### 需求

- 高可用性（3+ 副本）
- 自动扩缩容
- TLS/HTTPS
- 监控集成
- 备份策略
- 使用 Secret 管理敏感信息

### 准备步骤

```bash
# 1. 创建命名空间
kubectl create namespace production

# 2. 生成 JWT secret
JWT_SECRET=$(openssl rand -base64 32)

# 3. 创建 Secret
kubectl create secret generic openhands-prod-secrets \
  -n production \
  --from-literal=llmApiKey=sk-your-prod-key \
  --from-literal=jwtSecret=$JWT_SECRET

# 4. 验证 Secret
kubectl get secret openhands-prod-secrets -n production
```

### 安装命令

```bash
# 使用生产配置
helm install openhands . \
  -f values-production-example.yaml \
  --set secret.enabled=true \
  --set secret.existingSecret=openhands-prod-secrets \
  --set image.tag=v0.0.1 \
  --set image.runtime.tag=v0.0.1-runtime \
  --set image.agentServer.tag=v0.0.1-agent \
  --namespace production
```

### 生产配置

```yaml
# values-production.yaml
image:
  repository: docker.openhands.dev/openhands/openhands
  tag: v0.0.1  # 重要：固定版本
  pullPolicy: IfNotPresent

  runtime:
    repository: ghcr.io/openhands/runtime
    tag: v0.0.1-runtime
    pullPolicy: IfNotPresent

  agentServer:
    repository: ghcr.io/openhands/agent-server
    tag: v0.0.1-agent
    pullPolicy: IfNotPresent

replicaCount: 3

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

resources:
  requests:
    cpu: 2
    memory: 4Gi
  limits:
    cpu: 8
    memory: 16Gi

persistence:
  enabled: true
  size: 100Gi
  storageClass: fast-ssd
  accessMode: ReadWriteOnce

service:
  type: ClusterIP
  port: 3000

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: openhands.yourdomain.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: openhands-tls
      hosts:
        - openhands.yourdomain.com

openhands:
  llm:
    model: gpt-4o
    # apiKey 从 Secret 读取
    temperature: 0.0
    maxTokens: 0
  
  workspace:
    base: /opt/workspace_base
    initGit: true
  
  security:
    enableAnalyzer: true
    analyzerType: llm
  
  conversation:
    maxConcurrent: 10
    maxAgeSeconds: 864000

# 使用 Secret
secret:
  enabled: true
  existingSecret: openhands-prod-secrets

# Pod 中断预算
podDisruptionBudget:
  enabled: true
  minAvailable: 2

# ServiceMonitor for Prometheus
serviceMonitor:
  enabled: true
  namespace: monitoring
```

---

## 场景 4：自定义镜像版本（重点）

### 需求

- 完全控制所有镜像的版本
- 使用特定的镜像 tag
- 确保版本对应关系正确

### 为什么需要自定义？

OpenHands 由多个容器组成，每个使用不同的镜像：

1. **主应用容器**: `docker.openhands.dev/openhands/openhands`
2. **Runtime 容器**: `ghcr.io/openhands/runtime`
3. **Agent Server 容器**: `ghcr.io/openhands/agent-server`
4. **UV 容器**: `ghcr.io/astral-sh/uv`

这些镜像之间有版本对应关系，必须正确配置。

### 方法 1：命令行参数（快速）

```bash
helm install openhands . \
  --set image.repository=docker.openhands.dev/openhands/openhands \
  --set image.tag=v0.0.1 \
  --set image.runtime.repository=ghcr.io/openhands/runtime \
  --set image.runtime.tag=v0.0.1-runtime \
  --set image.agentServer.repository=ghcr.io/openhands/agent-server \
  --set image.agentServer.tag=v0.0.1-agent \
  --set image.uv.repository=ghcr.io/astral-sh/uv \
  --set image.uv.tag=latest \
  --set openhands.llm.apiKey=sk-... \
  --set openhands.llm.model=gpt-4o
```

### 方法 2：values 文件（推荐）

创建 `my-images.yaml`：

```yaml
# my-images.yaml
image:
  # 主应用镜像
  repository: docker.openhands.dev/openhands/openhands
  tag: v0.0.1
  pullPolicy: IfNotPresent
  
  # Runtime 镜像
  runtime:
    repository: ghcr.io/openhands/runtime
    tag: v0.0.1-runtime  # 通常与主版本对应
    pullPolicy: IfNotPresent
  
  # Agent Server 镜像
  agentServer:
    repository: ghcr.io/openhands/agent-server
    tag: v0.0.1-agent  # 通常与主版本对应
    pullPolicy: IfNotPresent
  
  # UV 镜像
  uv:
    repository: ghcr.io/astral-sh/uv
    tag: latest  # UV 通常使用 latest
    pullPolicy: IfNotPresent

openhands:
  llm:
    apiKey: sk-your-api-key
    model: gpt-4o
```

安装：

```bash
helm install openhands . -f my-images.yaml
```

### 方法 3：Makefile

```bash
make install-custom \
  IMAGE_TAG=v0.0.1 \
  RUNTIME_TAG=v0.0.1-runtime \
  AGENT_TAG=v0.0.1-agent \
  API_KEY=sk-your-key
```

### 版本对应关系

```
主版本:    v0.0.1
Runtime:    v0.0.1-runtime  或  v0.0.1
Agent:      v0.0.1-agent     或  v0.0.1
UV:         latest
```

### 查找正确的镜像版本

```bash
# 查看可用的 tags
curl -s https://ghcr.io/v2/openhands/runtime/tags/list | jq '.tags[]' | grep v0.0
curl -s https://ghcr.io/v2/openhands/agent-server/tags/list | jq '.tags[]' | grep v0.0

# 或查看 GitHub Releases
curl -s https://api.github.com/repos/OpenHands/OpenHands/releases/latest
```

### 升级镜像版本

```bash
# 升级到新版本
helm upgrade openhands . \
  -f my-images.yaml \
  --set image.tag=v0.0.2 \
  --set image.runtime.tag=v0.0.2-runtime \
  --set image.agentServer.tag=v0.0.2-agent \
  --reuse-values

# 查看升级状态
helm status openhands
kubectl rollout status deployment/openhands
```

---

## 场景 5：使用不同的 LLM Provider

### OpenAI

```bash
helm install openhands . \
  --set openhands.llm.apiKey=sk-... \
  --set openhands.llm.model=gpt-4o \
  --set openhands.llm.baseURL=https://api.openai.com/v1
```

### Anthropic Claude

```bash
helm install openhands . \
  --set openhands.llm.apiKey=sk-ant-... \
  --set openhands.llm.model=claude-3-opus-20240229 \
  --set openhands.llm.baseURL=https://api.anthropic.com/v1 \
  --set openhands.llm.customProvider=anthropic
```

### Azure OpenAI

```bash
helm install openhands . \
  --set openhands.llm.apiKey=your-azure-key \
  --set openhands.llm.model=gpt-4 \
  --set openhands.llm.baseURL=https://your-resource.openai.azure.com/
```

### 自定义 LLM Provider

```bash
helm install openhands . \
  --set openhands.llm.apiKey=your-key \
  --set openhands.llm.model=your-model-name \
  --set openhands.llm.baseURL=https://your-provider.com/v1 \
  --set openhands.llm.customProvider=your-provider
```

### 使用 Secret 存储 LLM 配置

```bash
# 创建 Secret
kubectl create secret generic custom-llm \
  --from-literal=llmApiKey=sk-... \
  --from-literal=llmBaseURL=https://api.anthropic.com/v1 \
  --from-literal=llmModel=claude-3-opus-20240229

# 使用 Secret
helm install openhands . \
  --set secret.enabled=true \
  --set secret.existingSecret=custom-llm
```

---

## 场景 6：GPU 支持

### 需求

- 使用 GPU 加速 LLM 推理
- 需要运行时配置 GPU 资源

### 配置步骤

```bash
# 1. 确保 Kubernetes 节点有 GPU
kubectl get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu"

# 2. 安装 NVIDIA Device Plugin
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.0/deployments/static/nvidia-device-plugin.yml

# 3. 部署 OpenHands with GPU
helm install openhands . \
  -f values-gpu.yaml
```

### GPU 配置文件

```yaml
# values-gpu.yaml
image:
  tag: v0.0.1
  runtime:
    tag: v0.0.1-runtime

resources:
  requests:
    cpu: 4
    memory: 8Gi
    nvidia.com/gpu: 1
  limits:
    cpu: 8
    memory: 16Gi
    nvidia.com/gpu: 1

openhands:
  sandbox:
    runtime: docker
    enableGPU: true
    cudaVisibleDevices: "0"  # 使用 GPU 0

kubernetes:
  runtimePrivileged: false
  runtimeNodeSelector:
    nvidia.com/gpu.present: "true"
  runtimeTolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
```

---

## 场景 7：多租户部署

### 需求

- 同一集群运行多个 OpenHands 实例
- 每个实例使用不同的配置
- 隔离的工作空间

### 部署命令

```bash
# 租户 1 - 开发团队
helm install openhands-dev . \
  -f values-dev-example.yaml \
  --set openhands.llm.apiKey=sk-dev-key \
  --namespace dev-team

# 租户 2 - QA 团队
helm install openhands-qa . \
  -f values-test.yaml \
  --set openhands.llm.apiKey=sk-qa-key \
  --namespace qa-team

# 租户 3 - 生产环境
helm install openhands-prod . \
  -f values-production.yaml \
  --set secret.enabled=true \
  --set secret.existingSecret=openhands-prod-secrets \
  --namespace production
```

### 查看所有实例

```bash
kubectl get all -A -l app.kubernetes.io/name=openhands
```

---

## 场景 8：离线/私有部署

### 需求

- 无法访问公网
- 使用私有镜像仓库
- 本地 LLM provider

### 准备步骤

```bash
# 1. 将镜像推送到私有仓库
docker pull docker.openhands.dev/openhands/openhands:v0.0.1
docker tag docker.openhands.dev/openhands/openhands:v0.0.1 registry.example.com/openhands/openhands:v0.0.1
docker push registry.example.com/openhands/openhands:v0.0.1

# 对所有镜像重复上述步骤
# - runtime
# - agent-server
# - uv

# 2. 创建 imagePullSecret
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=your-username \
  --docker-password=your-password
```

### 私有部署配置

```yaml
# values-private.yaml
image:
  repository: registry.example.com/openhands/openhands
  tag: v0.0.1
  pullPolicy: IfNotPresent

  runtime:
    repository: registry.example.com/openhands/runtime
    tag: v0.0.1-runtime
    pullPolicy: IfNotPresent

  agentServer:
    repository: registry.example.com/openhands/agent-server
    tag: v0.0.1-agent
    pullPolicy: IfNotPresent

  uv:
    repository: registry.example.com/astral-sh/uv
    tag: latest
    pullPolicy: IfNotPresent

imagePullSecrets:
  - name: regcred

openhands:
  llm:
    model: local-model
    baseURL: http://local-llm.internal:8000/v1
    apiKey: ""
```

### 部署

```bash
helm install openhands . \
  -f values-private.yaml \
  --namespace private-deployment
```

---

## 💡 最佳实践

### 1. 始终固定镜像版本

```yaml
# ✓ 推荐
image:
  tag: "v0.0.1"

# ✗ 不推荐
image:
  tag: "latest"
```

### 2. 使用 Secret 管理敏感信息

```bash
# ✓ 推荐
kubectl create secret generic llm-secret --from-literal=llmApiKey=sk-...
helm install openhands . --set secret.existingSecret=llm-secret

# ✗ 不推荐
helm install openhands . --set openhands.llm.apiKey=sk-...
```

### 3. 配置资源限制

```yaml
resources:
  requests:
    cpu: "2"
    memory: "4Gi"
  limits:
    cpu: "8"
    memory: "16Gi"
```

### 4. 启用持久化存储

```yaml
persistence:
  enabled: true
  size: 20Gi
  storageClass: fast-ssd
```

### 5. 使用命名空间隔离

```bash
kubectl create namespace dev
kubectl create namespace prod

helm install openhands-dev . -n dev
helm install openhands-prod . -n prod
```

---

## 🔗 相关文档

- [完整文档](./README.md)
- [快速开始](./QUICKSTART.md)
- [部署指南](./DEPLOYMENT_GUIDE.md)
- [配置参考](./values.yaml)
