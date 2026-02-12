# OpenHands Helm Chart - 完整说明

## 🎯 项目概述

这个 Helm Chart 为 OpenHands（AI 驱动的软件工程师）提供了完整的 Kubernetes 部署解决方案。

### ✨ 核心特性

1. **完全可定制的镜像版本** ⭐
   - 支持指定所有镜像的 tag
   - 确保版本对应关系正确
   - 支持自定义镜像仓库

2. **完整的 OpenHands 配置支持**
   - LLM 配置（多 provider 支持）
   - 工作区和存储配置
   - 安全和沙箱配置
   - Agent 能力开关

3. **生产就绪**
   - 持久化存储
   - 水平自动扩缩容 (HPA)
   - ConfigMap 和 Secret 管理
   - Ingress 和 TLS 支持
   - 健康检查
   - 资源限制

4. **开发友好**
   - Makefile 快捷命令
   - 验证脚本
   - 详细的文档
   - 示例配置

## 📦 镜像配置（最重要）

### 支持的镜像

| 镜像 | 用途 | 配置路径 | 示例 |
|------|------|----------|------|
| 主应用 | OpenHands 应用 | `image.repository` | `docker.openhands.dev/openhands/openhands` |
| 主应用 tag | 版本号 | `image.tag` | `v0.0.1` |
| Runtime | 沙箱环境 | `image.runtime.repository` | `ghcr.io/openhands/runtime` |
| Runtime tag | Runtime 版本 | `image.runtime.tag` | `v0.0.1-runtime` |
| Agent Server | Agent 服务 | `image.agentServer.repository` | `ghcr.io/openhands/agent-server` |
| Agent Server tag | Agent 版本 | `image.agentServer.tag` | `v0.0.1-agent` |
| UV | Python 包管理 | `image.uv.repository` | `ghcr.io/astral-sh/uv` |
| UV tag | UV 版本 | `image.uv.tag` | `latest` |

### 快速配置镜像版本

#### 方法 1: 命令行

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
  --set openhands.llm.apiKey=sk-your-key \
  --set openhands.llm.model=gpt-4o
```

#### 方法 2: values.yaml

创建 `my-values.yaml`:

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

openhands:
  llm:
    apiKey: sk-your-key
    model: gpt-4o
```

安装：

```bash
helm install openhands . -f my-values.yaml
```

#### 方法 3: Makefile

```bash
make install-custom \
  IMAGE_TAG=v0.0.1 \
  RUNTIME_TAG=v0.0.1-runtime \
  AGENT_TAG=v0.0.1-agent \
  API_KEY=sk-your-key
```

## 📁 文档结构

| 文档 | 用途 | 适合人群 |
|------|------|----------|
| [INDEX.md](./INDEX.md) | 包概览和索引 | 所有用户 |
| [README.md](./README.md) | 完整功能说明（中文） | 所有用户 |
| [README_EN.md](./README_EN.md) | Complete documentation (English) | English speakers |
| [QUICKSTART.md](./QUICKSTART.md) | 快速开始指南 | 新手用户 |
| [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) | 详细部署指南 | 运维人员 |
| [EXAMPLES.md](./EXAMPLES.md) | 使用场景示例 | 所有用户 |
| [values.yaml](./values.yaml) | 配置参数参考 | 配置人员 |
| [values-dev-example.yaml](./values-dev-example.yaml) | 开发环境示例 | 开发者 |
| [values-production-example.yaml](./values-production-example.yaml) | 生产环境示例 | 运维人员 |

## 🚀 快速开始

### 1. 前置准备

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

### 2. 准备 LLM API Key

你需要一个 LLM API 密钥：
- OpenAI: https://platform.openai.com/api-keys
- Anthropic: https://console.anthropic.com/
- 或其他兼容 provider

### 3. 安装 OpenHands

```bash
cd OpenHands/helm/openhands

# 使用默认配置
helm install openhands . \
  --set openhands.llm.apiKey=sk-your-key \
  --set openhands.llm.model=gpt-4o

# 或使用 Makefile
make install API_KEY=sk-your-key
```

### 4. 验证部署

```bash
# 查看 Pod 状态
kubectl get pods -l app.kubernetes.io/name=openhands -w

# 查看 Service
kubectl get svc openhands

# Port forward 访问
kubectl port-forward svc/openhands 3000:3000
```

访问: http://localhost:3000

## 🔧 主要配置项

### LLM 配置

```yaml
openhands:
  llm:
    model: gpt-4o          # 模型名称
    apiKey: sk-...          # API 密钥
    baseURL: ""             # API base URL（可选）
    temperature: 0.0        # 温度
    maxTokens: 0           # 最大 token（0 = 默认）
```

### 存储配置

```yaml
persistence:
  enabled: true
  size: 10Gi              # 存储大小
  storageClass: ""         # 存储类（空=默认）
  accessMode: ReadWriteOnce
```

### 资源配置

```yaml
resources:
  requests:
    cpu: 1
    memory: 2Gi
  limits:
    cpu: 4
    memory: 8Gi
```

### 网络配置

```yaml
service:
  type: ClusterIP         # ClusterIP, LoadBalancer, NodePort
  port: 3000

ingress:
  enabled: false          # 设为 true 启用
  className: nginx
  hosts:
    - host: openhands.example.com
```

## 📋 常见使用场景

### 场景 1: 开发环境

```bash
make install-dev API_KEY=sk-your-key
```

### 场景 2: 生产环境

```bash
# 1. 创建 Secret
kubectl create secret generic openhands-prod-secrets \
  --from-literal=llmApiKey=sk-your-prod-key

# 2. 部署
make install-prod
```

### 场景 3: 自定义镜像版本（核心功能）

```bash
make install-custom \
  IMAGE_TAG=v0.0.1 \
  RUNTIME_TAG=v0.0.1-runtime \
  AGENT_TAG=v0.0.1-agent \
  API_KEY=sk-your-key
```

### 场景 4: 使用不同的 LLM Provider

```bash
helm install openhands . \
  --set openhands.llm.model=claude-3-opus-20240229 \
  --set openhands.llm.baseURL=https://api.anthropic.com/v1 \
  --set openhands.llm.apiKey=sk-ant-your-key
```

### 场景 5: GPU 支持

```bash
helm install openhands . \
  -f EXAMPLES.md  # 查看 GPU 配置示例
```

## 🛠️ 维护命令

```bash
# 查看状态
helm status openhands
make status

# 查看日志
kubectl logs -l app.kubernetes.io/name=openhands --tail=100 -f
make logs

# 进入 Pod
kubectl exec -it <pod-name> -- /bin/bash
make shell

# 升级
helm upgrade openhands . -f new-values.yaml
make upgrade

# 回滚
helm rollback openhands

# 卸载
helm uninstall openhands
make uninstall
```

## 🔍 故障排查

### Pod 无法启动

```bash
# 1. 查看 Pod 状态
kubectl get pods
kubectl describe pod <pod-name>

# 2. 查看日志
kubectl logs <pod-name>
kubectl logs <pod-name> --previous

# 3. 检查事件
kubectl get events
```

### 常见问题

**Q: ImagePullBackOff 错误**

A: 镜像拉取失败，检查：
- 镜像名称和 tag 是否正确
- 需要创建 imagePullSecret（私有仓库）
- 网络是否可以访问镜像仓库

**Q: LLM API 调用失败**

A: 检查：
- API key 是否正确
- base URL 是否正确
- 网络是否可以访问 LLM API

**Q: PVC 绑定失败**

A: 检查：
- 存储类是否正确
- 集群是否有 PV provisioner
- 配额是否足够

## ✅ 生产环境检查清单

部署到生产环境前，确保：

- [ ] 已配置固定版本的镜像 tag（不使用 latest）
- [ ] 已使用 Secret 存储所有敏感信息
- [ ] 已配置足够的资源限制和请求
- [ ] 已启用持久化存储
- [ ] 已配置 Ingress 和 TLS（如需要）
- [ ] 已启用自动扩缩容（如需要）
- [ ] 已配置监控和日志收集
- [ ] 已设置备份策略
- [ ] 已测试升级和回滚流程
- [ ] 已配置告警规则

## 📚 相关资源

- **OpenHands 官方文档**: https://docs.openhands.dev
- **OpenHands GitHub**: https://github.com/OpenHands/OpenHands
- **Helm 官方文档**: https://helm.sh/docs
- **Kubernetes 官方文档**: https://kubernetes.io/docs

## 🤝 贡献

欢迎贡献！请：
1. 报告问题: https://github.com/OpenHands/OpenHands/issues
2. 提交 Pull Request
3. 改进文档
4. 分享使用经验

## 📄 许可证

Apache-2.0

---

## 💡 关键提示

1. **镜像版本管理**
   - 始终使用固定版本号
   - 确保主应用、Runtime、Agent Server 版本对应
   - 定期更新测试

2. **安全性**
   - 使用 Secret 存储敏感信息
   - 限制 Docker socket 访问
   - 配置 RBAC

3. **可观测性**
   - 集成 Prometheus 监控
   - 配置日志收集
   - 设置告警

4. **高可用**
   - 使用多副本
   - 启用 HPA
   - 配置 PDB

5. **性能优化**
   - 根据负载调整资源
   - 使用快速存储（SSD）
   - 考虑使用 GPU

---

**需要帮助？** 查看 [QUICKSTART.md](./QUICKSTART.md) 或 [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
