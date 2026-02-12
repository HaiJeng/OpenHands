# OpenHands Helm Chart - 创建完成

## ✅ 已创建的文件

### 📁 目录结构

```
helm/openhands/
├── Chart.yaml                          # Helm chart 元数据
├── values.yaml                         # 默认配置值（支持自定义所有镜像 tag）
├── values-dev-example.yaml             # 开发环境示例
├── values-production-example.yaml      # 生产环境示例
├── Makefile                            # 常用命令快捷方式
├── validate.sh                         # 部署前验证脚本
├── .helmignore                         # 打包忽略文件
│
├── templates/                          # Kubernetes 资源模板
│   ├── deployment.yaml                 # 主应用部署
│   ├── service.yaml                    # Service 服务
│   ├── ingress.yaml                    # Ingress 入口
│   ├── pvc.yaml                        # 持久化存储
│   ├── configmap.yaml                  # ConfigMap
│   ├── secret.yaml                     # Secret 密钥
│   ├── serviceaccount.yaml             # ServiceAccount
│   ├── hpa.yaml                        # 水平自动扩缩容
│   ├── _helpers.tpl                    # 模板辅助函数
│   └── NOTES.txt                       # 安装后提示
│
└── 📚 文档/
    ├── README.md                       # 中文完整文档
    ├── README_EN.md                    # 英文完整文档
    ├── README_MAIN.md                  # 主要说明文档
    ├── INDEX.md                        # 包索引
    ├── QUICKSTART.md                   # 快速开始指南
    ├── DEPLOYMENT_GUIDE.md             # 详细部署指南
    └── EXAMPLES.md                    # 使用场景示例
```

## 🎯 核心功能

### ⭐ 最重要：自定义镜像版本

本 Helm Chart 最重要的功能是**完全支持自定义所有镜像的 tag**：

#### 支持的镜像：

1. **主应用镜像**：`docker.openhands.dev/openhands/openhands`
   - 配置：`image.repository` 和 `image.tag`
   - 示例：`v0.0.1`

2. **Runtime 镜像**：`ghcr.io/openhands/runtime`
   - 配置：`image.runtime.repository` 和 `image.runtime.tag`
   - 示例：`v0.0.1-runtime`

3. **Agent Server 镜像**：`ghcr.io/openhands/agent-server`
   - 配置：`image.agentServer.repository` 和 `image.agentServer.tag`
   - 示例：`v0.0.1-agent`

4. **UV 镜像**：`ghcr.io/astral-sh/uv`
   - 配置：`image.uv.repository` 和 `image.uv.tag`
   - 示例：`latest`

### 配置方法

#### 方法 1：命令行参数

```bash
helm install openhands . \
  --set image.tag=v0.0.1 \
  --set image.runtime.tag=v0.0.1-runtime \
  --set image.agentServer.tag=v0.0.1-agent \
  --set image.uv.tag=latest \
  --set openhands.llm.apiKey=sk-your-key
```

#### 方法 2：values.yaml 文件

创建 `my-values.yaml`：

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

#### 方法 3：Makefile

```bash
make install-custom \
  IMAGE_TAG=v0.0.1 \
  RUNTIME_TAG=v0.0.1-runtime \
  AGENT_TAG=v0.0.1-agent \
  API_KEY=sk-your-key
```

## 📚 文档导航

| 文档 | 用途 |
|------|------|
| **[README_MAIN.md](./README_MAIN.md)** | 📖 **从这里开始** - 总体概览和快速指南 |
| **[INDEX.md](./INDEX.md)** | 📦 包索引和详细说明 |
| **[QUICKSTART.md](./QUICKSTART.md)** | 🚀 快速开始指南 |
| **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)** | 📖 详细部署指南和最佳实践 |
| **[EXAMPLES.md](./EXAMPLES.md)** | 💡 使用场景示例 |
| **[README.md](./README.md)** | 📋 完整功能说明（中文） |
| **[README_EN.md](./README_EN.md)** | 📋 Complete documentation (English) |
| **[values.yaml](./values.yaml)** | ⚙️ 配置参数参考 |

## 🚀 快速使用

### 1. 前置准备

```bash
# 安装 kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# 安装 helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 验证
kubectl version --client
helm version
```

### 2. 进入 Chart 目录

```bash
cd OpenHands/helm/openhands
```

### 3. 安装 OpenHands

```bash
# 最简单的安装（使用默认 latest 镜像）
helm install openhands . \
  --set openhands.llm.apiKey=sk-your-api-key \
  --set openhands.llm.model=gpt-4o

# 使用固定版本的镜像（推荐）
helm install openhands . \
  --set image.tag=v0.0.1 \
  --set image.runtime.tag=v0.0.1-runtime \
  --set image.agentServer.tag=v0.0.1-agent \
  --set image.uv.tag=latest \
  --set openhands.llm.apiKey=sk-your-api-key \
  --set openhands.llm.model=gpt-4o

# 使用 Makefile（推荐）
make install API_KEY=sk-your-api-key

# 生产环境
make install-prod
```

### 4. 访问 OpenHands

```bash
# 端口转发
kubectl port-forward svc/openhands 3000:3000

# 在浏览器打开
open http://localhost:3000
```

## 🔧 主要配置

### 1. LLM 配置（必需）

```yaml
openhands:
  llm:
    model: gpt-4o           # 可选：gpt-4o-mini, claude-3-opus-20240229
    apiKey: sk-...          # 必需：API 密钥
    baseURL: ""             # 可选：自定义 API 端点
    temperature: 0.0
```

### 2. 存储配置

```yaml
persistence:
  enabled: true
  size: 10Gi              # 根据需求调整
  storageClass: ""         # 空=默认存储类
```

### 3. 资源配置

```yaml
resources:
  requests:
    cpu: 1
    memory: 2Gi
  limits:
    cpu: 4
    memory: 8Gi
```

### 4. 网络配置

```yaml
service:
  type: ClusterIP         # 选项：ClusterIP, LoadBalancer, NodePort
  port: 3000

ingress:
  enabled: true          # 设为 true 启用
  className: nginx
  hosts:
    - host: openhands.example.com
```

## 🛠️ 常用命令

```bash
# 查看状态
helm status openhands
kubectl get pods -l app.kubernetes.io/name=openhands

# 查看日志
kubectl logs -l app.kubernetes.io/name=openhands --tail=100 -f

# 进入 Pod
kubectl exec -it <pod-name> -- /bin/bash

# 升级
helm upgrade openhands . \
  --set image.tag=v0.0.2 \
  --set image.runtime.tag=v0.0.2-runtime \
  --reuse-values

# 回滚
helm rollback openhands

# 卸载
helm uninstall openhands
```

## 📋 检查清单

部署前检查：

- [ ] Kubernetes 集群可访问
- [ ] kubectl 和 helm 已安装
- [ ] LLM API key 已准备
- [ ] 镜像版本已确认（不使用 latest）
- [ ] 存储类已配置
- [ ] 资源配额足够

## 🎓 学习路径

1. **新手用户**
   - 阅读 [README_MAIN.md](./README_MAIN.md)
   - 按照 [QUICKSTART.md](./QUICKSTART.md) 操作
   - 尝试第一个示例

2. **进阶用户**
   - 阅读 [INDEX.md](./INDEX.md)
   - 查看 [EXAMPLES.md](./EXAMPLES.md)
   - 配置不同的 LLM provider

3. **运维人员**
   - 阅读 [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
   - 使用 [values-production-example.yaml](./values-production-example.yaml)
   - 配置监控和告警

## 💡 最佳实践

### ✅ 推荐做法

1. **固定镜像版本**
   ```yaml
   image:
     tag: "v0.0.1"  # ✓ Good
   ```

2. **使用 Secret 管理 API key**
   ```bash
   kubectl create secret generic llm-secret --from-literal=llmApiKey=sk-...
   helm install openhands . --set secret.existingSecret=llm-secret
   ```

3. **配置资源限制**
   ```yaml
   resources:
     requests:
       cpu: 1
       memory: 2Gi
   ```

4. **启用持久化存储**
   ```yaml
   persistence:
     enabled: true
     size: 20Gi
   ```

### ❌ 不推荐做法

1. **使用 latest tag**
   ```yaml
   image:
     tag: "latest"  # ✗ Bad
   ```

2. **明文存储 API key**
   ```yaml
   openhands:
     llm:
       apiKey: "sk-..."  # ✗ Don't commit to git
   ```

3. **无资源限制**
   ```yaml
   resources: {}  # ✗ Bad
   ```

## 🔗 相关资源

- **OpenHands 官方文档**: https://docs.openhands.dev
- **OpenHands GitHub**: https://github.com/OpenHands/OpenHands
- **Helm 官方文档**: https://helm.sh/docs
- **Kubernetes 官方文档**: https://kubernetes.io/docs

## 🆘 获取帮助

遇到问题？

1. 查看 [QUICKSTART.md](./QUICKSTART.md) 的故障排查部分
2. 查看 [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) 的常见问题
3. 运行 `./validate.sh` 检查配置
4. 提交 Issue: https://github.com/OpenHands/OpenHands/issues

## 📄 许可证

Apache-2.0

---

**开始使用**: 阅读 [README_MAIN.md](./README_MAIN.md) 并运行 `make install API_KEY=sk-your-key`
