# OpenHands Helm Chart 部署完整指南

本指南提供了使用 Helm Chart 在 Kubernetes 上部署 OpenHands 的完整步骤。

## 📚 目录

1. [前置准备](#前置准备)
2. [理解架构](#理解架构)
3. [安装方式](#安装方式)
4. [配置镜像版本](#配置镜像版本)（重点）
5. [配置 LLM](#配置-llm)
6. [存储配置](#存储配置)
7. [网络配置](#网络配置)
8. [生产环境部署](#生产环境部署)
9. [故障排查](#故障排查)
10. [最佳实践](#最佳实践)

---

## 前置准备

### 1. 安装必需工具

```bash
# 安装 kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# 安装 helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 验证安装
kubectl version --client
helm version
```

### 2. 准备 Kubernetes 集群

确保你有以下之一：

- Minikube（本地开发）
- Kind（本地测试）
- 云平台 Kubernetes 集群（GKE, EKS, AKS 等）
- 自托管 Kubernetes 集群

### 3. 准备 LLM API 密钥

OpenHands 需要一个 LLM API 密钥：

- OpenAI API Key: [https://platform.openai.com/api-keys](https://platform.openai.com/api-keys)
- 或者其他兼容的 LLM provider

---

## 理解架构

OpenHands 部署包含以下组件：

```
┌─────────────────────────────────────┐
│     Kubernetes Cluster            │
│                                  │
│  ┌────────────────────────┐      │
│  │   OpenHands Pod       │      │
│  │                       │      │
│  │  ┌─────────────────┐  │      │
│  │  │ Main Container │  │      │
│  │  │ - Web Server   │  │      │
│  │  │ - Agent Logic  │  │      │
│  │  └─────────────────┘  │      │
│  │           │              │      │
│  │           ▼              │      │
│  │  ┌─────────────────┐  │      │
│  │  │ Runtime Image   │  │      │
│  │  │ (DinD/Sandbox) │  │      │
│  │  └─────────────────┘  │      │
│  └────────────────────────┘      │
│           │                     │
│  ┌────────┴────────────────┐   │
│  │                         │   │
│  │ Persistent Volume         │   │
│  │ - Workspace data         │   │
│  │ - Config files          │   │
│  └─────────────────────────┘   │
└───────────────────────────────────┘
```

**关键镜像组件：**

1. **主应用镜像** (`docker.openhands.dev/openhands/openhands`)
   - Web 服务器和 API
   - Agent 逻辑
   - 前端界面

2. **Runtime 镜像** (`ghcr.io/openhands/runtime`)
   - 代码执行环境
   - 沙箱容器
   - 工具链

3. **Agent Server 镜像** (`ghcr.io/openhands/agent-server`)
   - Agent 服务端点
   - 任务分发

4. **UV 镜像** (`ghcr.io/astral-sh/uv`)
   - Python 包管理
   - 依赖安装

---

## 安装方式

### 方式 1: 快速安装（适合测试）

```bash
cd helm/openhands

helm install openhands . \
  --set openhands.llm.apiKey=sk-your-api-key \
  --set openhands.llm.model=gpt-4o
```

### 方式 2: 自定义 values 文件（推荐）

创建 `my-values.yaml`：

```yaml
image:
  tag: v0.0.1
  
openhands:
  llm:
    apiKey: sk-your-api-key
    model: gpt-4o
```

安装：

```bash
helm install openhands . -f my-values.yaml
```

### 方式 3: 使用 Makefile（开发友好）

```bash
# 快速安装
make install API_KEY=sk-your-api-key

# 生产安装
make install-prod

# 开发安装
make install-dev API_KEY=sk-your-key

# 自定义镜像版本
make install-custom \
  IMAGE_TAG=v0.0.1 \
  RUNTIME_TAG=v0.0.1-runtime \
  AGENT_TAG=v0.0.1-agent \
  API_KEY=sk-your-key
```

### 方式 4: 先验证后安装（生产推荐）

```bash
# 运行验证脚本
./validate.sh

# 如果验证通过，安装
helm install openhands . \
  --set openhands.llm.apiKey=sk-your-api-key \
  --set openhands.llm.model=gpt-4o
```

---

## 配置镜像版本

这是**最重要**的配置选项。你必须明确指定每个镜像的版本。

### 理解镜像版本对应关系

OpenHands 使用多个镜像，它们之间有版本对应关系：

| 组件 | 镜像路径 | 版本策略 |
|------|----------|---------|
| 主应用 | `docker.openhands.dev/openhands/openhands` | 必须匹配发布版本 |
| Runtime | `ghcr.io/openhands/runtime` | 必须匹配主应用版本 |
| Agent Server | `ghcr.io/openhands/agent-server` | 必须匹配主应用版本 |
| UV | `ghcr.io/astral-sh/uv` | 通常使用 latest |

### 方法 1: 使用命令行参数

```bash
helm install openhands . \
  --set image.tag=v0.0.1 \
  --set image.runtime.tag=v0.0.1-runtime \
  --set image.agentServer.tag=v0.0.1-agent \
  --set image.uv.tag=latest \
  --set openhands.llm.apiKey=sk-... \
  --set openhands.llm.model=gpt-4o
```

### 方法 2: 使用 values 文件（推荐）

创建 `custom-images.yaml`：

```yaml
# 主应用配置
image:
  repository: docker.openhands.dev/openhands/openhands
  tag: v0.0.1  # 具体版本号
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

# UV 镜像（通常使用 latest）
uv:
  repository: ghcr.io/astral-sh/uv
  tag: latest
  pullPolicy: IfNotPresent
```

安装：

```bash
helm install openhands . -f custom-images.yaml \
  --set openhands.llm.apiKey=sk-...
```

### 方法 3: 使用 Makefile

```bash
make install-custom \
  IMAGE_TAG=v0.0.1 \
  RUNTIME_TAG=v0.0.1-runtime \
  AGENT_TAG=v0.0.1-agent \
  API_KEY=sk-your-key
```

### 如何查找正确的镜像版本？

1. **查看 GitHub Releases**:
   ```bash
   # 获取最新版本
   curl -s https://api.github.com/repos/OpenHands/OpenHands/releases/latest | grep tag_name
   ```

2. **查看 Docker Hub**:
   - 检查 `openhands/openhands` 的 tags
   - 检查 `openhands/runtime` 的 tags
   - 检查 `openhands/agent-server` 的 tags

3. **版本对应关系**:
   ```
   主版本: v0.0.1
   Runtime: v0.0.1-runtime 或 v0.0.1
   Agent: v0.0.1-agent 或 v0.0.1
   ```

### 镜像版本更新策略

```bash
# 1. 查看当前版本
helm get values openhands

# 2. 更新到新版本
helm upgrade openhands . \
  --set image.tag=v0.0.2 \
  --set image.runtime.tag=v0.0.2-runtime \
  --set image.agentServer.tag=v0.0.2-agent \
  --reuse-values

# 3. 验证升级
helm status openhands
kubectl rollout status deployment/openhands
```

---

## 配置 LLM

OpenHands 需要一个 LLM provider 来运行 AI agent。

### 支持的 LLM Providers

1. **OpenAI** (默认)
2. **Anthropic** (Claude)
3. **Mistral AI**
4. **任何兼容 OpenAI API 的 provider**

### 配置 OpenAI

```bash
helm install openhands . \
  --set openhands.llm.apiKey=sk-your-openai-key \
  --set openhands.llm.model=gpt-4o \
  --set openhands.llm.baseURL=https://api.openai.com/v1
```

### 配置 Anthropic Claude

```bash
helm install openhands . \
  --set openhands.llm.apiKey=sk-ant-your-key \
  --set openhands.llm.model=claude-3-opus-20240229 \
  --set openhands.llm.baseURL=https://api.anthropic.com/v1 \
  --set openhands.llm.customProvider=anthropic
```

### 配置 Azure OpenAI

```bash
helm install openhands . \
  --set openhands.llm.apiKey=your-azure-key \
  --set openhands.llm.model=gpt-4 \
  --set openhands.llm.baseURL=https://your-resource.openai.azure.com/
```

### 使用 Secret 管理 API Key（生产推荐）

```bash
# 1. 创建 Secret
kubectl create secret generic openhands-llm \
  --from-literal=llmApiKey=sk-your-key \
  --from-literal=llmBaseURL=https://api.openai.com/v1

# 2. 部署时使用 Secret
helm install openhands . \
  --set secret.enabled=true \
  --set secret.existingSecret=openhands-llm
```

---

## 存储配置

OpenHands 需要持久化存储来保存：
- 工作区文件
- Agent 状态
- 配置文件
- 缓存数据

### 默认配置

默认启用 10Gi 的 PVC：

```yaml
persistence:
  enabled: true
  size: 10Gi
  accessMode: ReadWriteOnce
  storageClass: ""  # 使用默认存储类
```

### 自定义存储大小

```bash
# 小型部署
helm install openhands . \
  --set persistence.size=5Gi

# 大型部署
helm install openhands . \
  --set persistence.size=100Gi
```

### 指定存储类

```bash
# 使用 SSD 存储
helm install openhands . \
  --set persistence.storageClass=fast-ssd

# 使用 NFS
helm install openhands . \
  --set persistence.storageClass=nfs
```

### 使用现有的 PVC

```bash
# 1. 创建 PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: openhands-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: fast-ssd
EOF

# 2. 部署时使用
helm install openhands . \
  --set persistence.enabled=true \
  --set persistence.existingClaim=openhands-data
```

### 查看存储使用情况

```bash
# 查看 PVC 状态
kubectl get pvc

# 查看存储使用
kubectl exec -it <pod-name> -- df -h

# 扩容 PVC（需要存储类支持）
kubectl patch pvc openhands-data \
  -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
```

---

## 网络配置

### Service 配置

默认使用 ClusterIP：

```yaml
service:
  type: ClusterIP
  port: 3000
```

### LoadBalancer（云环境）

```bash
helm install openhands . \
  --set service.type=LoadBalancer
```

访问：

```bash
EXTERNAL_IP=$(kubectl get svc openhands -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Access OpenHands at: http://$EXTERNAL_IP:3000"
```

### NodePort（裸金属/本地）

```bash
helm install openhands . \
  --set service.type=NodePort
```

### Port Forward（本地开发）

```bash
# 方法 1: 手动
kubectl port-forward svc/openhands 3000:3000

# 方法 2: 使用 Makefile
make port-forward
```

访问：http://localhost:3000

### Ingress（生产推荐）

#### 使用 NGINX Ingress

```bash
helm install openhands . \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.hosts[0].host=openhands.example.com \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix
```

#### 启用 TLS（使用 cert-manager）

```bash
helm install openhands . \
  --set ingress.enabled=true \
  --set ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod \
  --set ingress.hosts[0].host=openhands.example.com \
  --set ingress.tls[0].secretName=openhands-tls \
  --set ingress.tls[0].hosts[0]=openhands.example.com
```

---

## 生产环境部署

### 完整的生产部署清单

#### 1. 创建命名空间和资源配额

```bash
kubectl create namespace openhands-production

kubectl apply -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: openhands-quota
  namespace: openhands-production
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    persistentvolumeclaims: "10"
EOF
```

#### 2. 创建 Secret 存储敏感信息

```bash
# LLM API Key
LLM_KEY="sk-your-production-key"

# JWT Secret
JWT_SECRET=$(openssl rand -base64 32)

# 创建 Secret
kubectl create secret generic openhands-secrets \
  -n openhands-production \
  --from-literal=llmApiKey=$LLM_KEY \
  --from-literal=jwtSecret=$JWT_SECRET

# 验证
kubectl get secret openhands-secrets -n openhands-production
```

#### 3. 配置持久化存储

```bash
# 创建 StorageClass（如果需要）
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
allowVolumeExpansion: true
reclaimPolicy: Retain
EOF
```

#### 4. 部署 OpenHands

```bash
helm install openhands . \
  -n openhands-production \
  -f values-production-example.yaml \
  --set secret.enabled=true \
  --set secret.existingSecret=openhands-secrets \
  --set persistence.storageClass=fast-ssd \
  --set persistence.size=100Gi \
  --set replicaCount=3 \
  --set autoscaling.enabled=true \
  --set autoscaling.minReplicas=3 \
  --set autoscaling.maxReplicas=10
```

#### 5. 配置 Ingress 和 TLS

```bash
# 安装 cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# 创建 ClusterIssuer
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# 启用 Ingress
helm upgrade openhands . \
  -n openhands-production \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod \
  --set ingress.hosts[0].host=openhands.yourdomain.com \
  --set ingress.tls[0].secretName=openhands-tls \
  --set ingress.tls[0].hosts[0]=openhands.yourdomain.com
```

#### 6. 配置监控和告警

```bash
# ServiceMonitor for Prometheus
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: openhands
  namespace: openhands-production
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: openhands
  endpoints:
  - port: http
EOF
```

---

## 故障排查

### Pod 无法启动

```bash
# 1. 查看 Pod 状态
kubectl get pods -n openhands-production

# 2. 查看 Pod 详情
kubectl describe pod <pod-name> -n openhands-production

# 3. 查看日志
kubectl logs <pod-name> -n openhands-production

# 4. 查看事件
kubectl get events -n openhands-production --sort-by='.lastTimestamp'
```

### 常见问题和解决方案

#### 问题 1: ImagePullBackOff

**原因**: 镜像不存在或无权限访问

**解决**:
```bash
# 1. 检查镜像标签是否正确
kubectl describe pod <pod-name> | grep Image

# 2. 创建 imagePullSecret（如果使用私有仓库）
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=your-username \
  --docker-password=your-token

# 3. 更新部署
helm upgrade openhands . \
  --set imagePullSecrets[0].name=regcred
```

#### 问题 2: CrashLoopBackOff

**原因**: 应用启动失败，配置错误或资源不足

**解决**:
```bash
# 1. 查看日志找出错误
kubectl logs <pod-name> --previous

# 2. 检查资源限制
kubectl describe pod <pod-name>

# 3. 增加资源
helm upgrade openhands . \
  --set resources.requests.memory=4Gi \
  --set resources.limits.memory=8Gi
```

#### 问题 3: PVC Pending

**原因**: 存储类配置错误或集群中没有 PV provisioner

**解决**:
```bash
# 1. 检查存储类
kubectl get storageclass

# 2. 检查 PVC
kubectl describe pvc openhands-data

# 3. 使用正确的存储类
helm upgrade openhands . \
  --set persistence.storageClass=standard
```

#### 问题 4: LLM API 调用失败

**原因**: API key 错误或网络问题

**解决**:
```bash
# 1. 验证 Secret
kubectl get secret openhands-secrets -o yaml

# 2. 检查环境变量
kubectl exec -it <pod-name> -- env | grep LLM

# 3. 更新 Secret
kubectl create secret generic openhands-secrets \
  --from-literal=llmApiKey=new-key \
  --dry-run=client -o yaml | kubectl apply -f -

# 4. 重启 Pod
kubectl rollout restart deployment/openhands
```

---

## 最佳实践

### 1. 镜像版本管理

✅ **推荐**:
- 固定具体版本号
- 使用语义化版本
- 定期更新测试

```yaml
image:
  tag: "v0.0.1"  # Good
```

❌ **不推荐**:
```yaml
image:
  tag: "latest"  # Bad for production
  tag: "main"    # Unstable
```

### 2. 资源配置

根据实际负载调整：

```yaml
resources:
  requests:
    cpu: "2"
    memory: "4Gi"
  limits:
    cpu: "8"
    memory: "16Gi"
```

### 3. 安全配置

- 使用 Secret 存储敏感信息
- 启用 RBAC
- 限制 Pod 特权
- 使用 NetworkPolicy

### 4. 高可用配置

```yaml
replicaCount: 3

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10

podDisruptionBudget:
  minAvailable: 2
```

### 5. 监控和日志

- 集成 Prometheus
- 配置日志收集
- 设置告警规则

### 6. 备份策略

- 定期备份 PVC
- 备份 Helm release
- 文档化配置

---

## 下一步

- 查看 [QUICKSTART.md](./QUICKSTART.md) 快速开始
- 查看 [README.md](./README.md) 完整文档
- 查看 [values.yaml](./values.yaml) 所有配置选项
- 查看 [values-production-example.yaml](./values-production-example.yaml) 生产示例

获取帮助：
- [GitHub Issues](https://github.com/OpenHands/OpenHands/issues)
- [官方文档](https://docs.openhands.dev)
- [社区讨论](https://github.com/OpenHands/OpenHands/blob/main/COMMUNITY.md)
