# OpenHands Helm Chart 包说明

本目录包含了完整的 OpenHands Kubernetes Helm Chart 包，用于在 Kubernetes 集群上部署 OpenHands 应用。

## 📦 包结构

```
openhands/
├── Chart.yaml                          # Helm chart 元数据
├── values.yaml                         # 默认配置值
├── values-dev-example.yaml             # 开发环境配置示例
├── values-production-example.yaml      # 生产环境配置示例
├── Makefile                            # 常用命令快捷方式
├── validate.sh                         # 部署前验证脚本
├── .helmignore                         # Helm 打包忽略文件
│
├── templates/                          # Kubernetes 资源模板
│   ├── deployment.yaml                 # 主应用部署
│   ├── service.yaml                    # Service 服务
│   ├── ingress.yaml                    # Ingress 入口
│   ├── pvc.yaml                        # 持久化存储卷声明
│   ├── configmap.yaml                  # ConfigMap 配置
│   ├── secret.yaml                     # Secret 密钥
│   ├── serviceaccount.yaml             # ServiceAccount
│   ├── hpa.yaml                        # 水平自动扩缩容
│   ├── _helpers.tpl                    # 模板辅助函数
│   └── NOTES.txt                       # 安装后提示信息
│
└── 文档/
    ├── README.md                       # 完整使用文档（中文）
    ├── README_EN.md                    # 完整使用文档（英文）
    ├── QUICKSTART.md                   # 快速开始指南
    └── DEPLOYMENT_GUIDE.md             # 详细部署指南
```

## 🎯 核心功能

### 1. **完全可定制的镜像版本**（最重要的功能）

你可以指定所有使用镜像的 tag：

```bash
# 通过命令行
helm install openhands . \
  --set image.tag=v0.0.1 \
  --set image.runtime.tag=v0.0.1-runtime \
  --set image.agentServer.tag=v0.0.1-agent \
  --set image.uv.tag=latest

# 或通过 values.yaml
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

### 2. **完整的 OpenHands 配置支持**

支持所有 OpenHands 配置项：
- LLM 配置（模型、API key、base URL）
- 工作区配置
- 安全设置
- Agent 能力开关
- 沙箱运行时配置
- 浏览器设置
- 会话管理

### 3. **生产就绪特性**

- 持久化存储配置
- 水平自动扩缩容 (HPA)
- ConfigMap 和 Secret 管理
- Ingress 和 TLS 支持
- 资源限制和请求
- 健康检查（liveness/readiness probes）
- Pod 中断预算

### 4. **开发友好**

- Makefile 快捷命令
- 验证脚本
- 详细的文档
- 示例配置文件
- 安装后提示信息

## 🚀 快速使用

### 安装

```bash
# 1. 最简单的安装
helm install openhands . \
  --set openhands.llm.apiKey=sk-your-key \
  --set openhands.llm.model=gpt-4o

# 2. 使用自定义 values 文件
helm install openhands . -f my-values.yaml

# 3. 使用 Makefile
make install API_KEY=sk-your-key

# 4. 生产环境
make install-prod
```

### 访问

```bash
# 方式 1: Port Forward
kubectl port-forward svc/openhands 3000:3000
# 访问 http://localhost:3000

# 方式 2: LoadBalancer
helm upgrade openhands . --set service.type=LoadBalancer

# 方式 3: Ingress
helm upgrade openhands . --set ingress.enabled=true
```

### 管理和维护

```bash
# 查看状态
helm status openhands
make status

# 查看日志
kubectl logs -l app.kubernetes.io/name=openhands --tail=100 -f
make logs

# 升级
helm upgrade openhands . -f new-values.yaml
make upgrade

# 回滚
helm rollback openhands

# 卸载
helm uninstall openhands
make uninstall
```

## 📚 文档导航

| 文档 | 用途 | 适合人群 |
|------|------|----------|
| [README.md](./README.md) | 完整功能说明和配置参考 | 所有用户 |
| [QUICKSTART.md](./QUICKSTART.md) | 快速开始和常见操作 | 新手用户 |
| [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) | 详细部署指南和最佳实践 | 运维人员 |
| [values.yaml](./values.yaml) | 配置参数详细说明 | 配置人员 |
| [values-dev-example.yaml](./values-dev-example.yaml) | 开发环境配置示例 | 开发者 |
| [values-production-example.yaml](./values-production-example.yaml) | 生产环境配置示例 | 运维人员 |

## 🔑 关键配置说明

### 1. 镜像版本配置（核心）

**为什么重要**: OpenHands 由多个容器组成，每个容器使用不同的镜像。这些镜像之间有版本对应关系，必须正确配置才能正常运行。

**配置方法**:
- 始终使用具体的版本号，不要使用 `latest`
- Runtime 和 Agent Server 的版本通常与主版本对应
- UV 镜像可以使用 `latest`（相对独立）

**示例**:
```yaml
# 推荐 ✓
image:
  tag: "v0.0.1"
  runtime:
    tag: "v0.0.1-runtime"
  agentServer:
    tag: "v0.0.1-agent"

# 不推荐 ✗
image:
  tag: "latest"  # 无法追踪具体版本
```

### 2. LLM 配置（必需）

OpenHands 必须配置 LLM 才能工作：

```yaml
openhands:
  llm:
    model: gpt-4o           # 模型名称
    apiKey: sk-...          # API 密钥
    baseURL: https://...    # API 地址（可选）
    temperature: 0.0        # 温度参数（可选）
```

**生产环境建议**: 使用 Secret 存储 API key：

```bash
kubectl create secret generic openhands-llm \
  --from-literal=llmApiKey=sk-your-key

helm install openhands . \
  --set secret.enabled=true \
  --set secret.existingSecret=openhands-llm
```

### 3. 存储配置（重要）

OpenHands 需要持久化存储来保存工作区和数据：

```yaml
persistence:
  enabled: true
  size: 10Gi              # 根据需要调整
  storageClass: fast-ssd  # 使用合适的存储类
  accessMode: ReadWriteOnce
```

### 4. 资源配置（性能）

根据负载调整资源限制：

```yaml
resources:
  requests:
    cpu: "2"
    memory: "4Gi"
  limits:
    cpu: "8"
    memory: "16Gi"
```

## ⚠️ 重要注意事项

### 安全建议

1. **永远不要**在 values.yaml 中明文存储 API 密钥
2. **始终使用** Kubernetes Secret 管理敏感信息
3. **限制 Docker socket 访问**（如果启用了）
4. **启用 RBAC** 限制 Pod 权限
5. **使用 NetworkPolicy** 限制网络访问
6. **定期更新**镜像版本以获取安全补丁

### 生产环境检查清单

- [ ] 已配置固定版本的镜像 tag
- [ ] 已使用 Secret 存储所有敏感信息
- [ ] 已配置足够的资源限制
- [ ] 已启用持久化存储
- [ ] 已配置 Ingress 和 TLS
- [ ] 已启用自动扩缩容（如需要）
- [ ] 已配置监控和日志收集
- [ ] 已设置备份策略
- [ ] 已测试故障恢复流程
- [ ] 已配置告警规则

### 常见问题

**Q: 如何指定多个镜像的版本？**

A: 使用 `image.*` 参数：
```bash
helm install openhands . \
  --set image.tag=v0.0.1 \
  --set image.runtime.tag=v0.0.1-runtime \
  --set image.agentServer.tag=v0.0.1-agent
```

**Q: 可以使用其他 LLM provider 吗？**

A: 可以，只需修改 LLM 配置：
```bash
helm install openhands . \
  --set openhands.llm.model=claude-3-opus-20240229 \
  --set openhands.llm.baseURL=https://api.anthropic.com/v1 \
  --set openhands.llm.apiKey=sk-ant-...
```

**Q: 如何升级镜像版本？**

A: 使用 helm upgrade：
```bash
helm upgrade openhands . \
  --set image.tag=v0.0.2 \
  --set image.runtime.tag=v0.0.2-runtime \
  --set image.agentServer.tag=v0.0.2-agent \
  --reuse-values
```

**Q: Docker socket 挂载失败怎么办？**

A: 可以使用 Kubernetes runtime 替代 Docker runtime：
```bash
helm install openhands . \
  --set dockerSocket.enabled=false \
  --set openhands.sandbox.runtime=kubernetes
```

## 🛠️ 故障排查

### 常用命令

```bash
# 查看所有资源
kubectl get all -l app.kubernetes.io/name=openhands

# 查看 Pod 日志
kubectl logs -l app.kubernetes.io/name=openhands --tail=100 -f

# 进入 Pod
kubectl exec -it <pod-name> -- /bin/bash

# 查看 PVC 状态
kubectl get pvc -l app.kubernetes.io/name=openhands

# 查看 Ingress
kubectl get ingress openhands

# 查看事件
kubectl get events --sort-by='.lastTimestamp'
```

### 验证部署

```bash
# 1. 运行验证脚本
./validate.sh

# 2. 检查 Helm chart 语法
helm lint .

# 3. 渲染模板（不安装）
helm template openhands .

# 4. 模拟安装
helm install openhands . --dry-run --debug
```

## 📖 更多资源

- **OpenHands 官方文档**: https://docs.openhands.dev
- **OpenHands GitHub**: https://github.com/OpenHands/OpenHands
- **Helm 官方文档**: https://helm.sh/docs
- **Kubernetes 官方文档**: https://kubernetes.io/docs

## 🤝 贡献

如果你发现问题或有改进建议，欢迎：
1. 提交 Issue: https://github.com/OpenHands/OpenHands/issues
2. 创建 Pull Request
3. 参与社区讨论

## 📄 许可证

Apache-2.0

---

**注意**: 本 Helm Chart 由社区维护，不是 OpenHands 官方产品。使用时请遵守相关服务条款。
