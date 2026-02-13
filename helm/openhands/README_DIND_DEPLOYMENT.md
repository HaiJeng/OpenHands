# OpenHands Docker-in-Docker 部署说明

## 📋 概述

本分支修改了 OpenHands Helm Chart，使其支持连接到远程 Docker-in-Docker (DinD) 服务，从而实现每个会话创建独立 Docker 容器的功能。

### 问题背景

OpenHands V1 应用服务器的 Kubernetes 部署默认使用 `ProcessSandboxService`，它不会为每个会话创建独立的 Kubernetes Pod。而 V0 的 `KubernetesRuntime` 已弃用。

### 解决方案

使用 **Docker Runtime** + **远程 DinD 服务** 的方式：
- OpenHands 连接到远程 DinD 服务的 Docker Daemon
- 每个会话创建独立的 Docker 容器（在 DinD Pod 中运行）
- 可以使用 `docker ps` 查看运行中的会话容器

---

## 🚀 完整部署步骤

### 前提条件

1. ✅ 已部署 DinD 服务（ClusterIP: `172.11.176.38:2375`）
2. ✅ DinD Service 名称: `docker-dind`
3. ✅ Kubernetes 命名空间: `openhands-dev`

### Step 1: 部署 OpenHands

```bash
# 方式 1：使用修改后的生产配置（推荐）
helm upgrade openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace openhands-dev \
  --reuse-values

# 方式 2：使用专用 DinD 配置文件
helm upgrade openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  -f ./openhands/values-k8s-production-with-dind.yaml \
  --namespace openhands-dev \
  --reuse-values

# 方式 3：全新安装
helm install openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace openhands-dev
```

### Step 2: 设置 LLM API Key

```bash
# 方式 1：通过命令行设置
helm upgrade openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace openhands-dev \
  --set openhands.llm.apiKey="sk-your-api-key-here" \
  --set openhands.llm.model=gpt-4o \
  --reuse-values

# 方式 2：直接编辑 values-k8s-production.yaml
# 修改第 30 行：
# apiKey: "sk-your-api-key-here"
```

### Step 3: 等待 Pod 就绪

```bash
# 等待 OpenHands Pod Ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=openhands \
  -n openhands-dev \
  --timeout=300s

# 查看 Pod 状态
kubectl get pods -n openhands-dev -l app.kubernetes.io/name=openhands
```

### Step 4: 验证 Docker 连接

```bash
# 获取 OpenHands Pod 名称
OPENHANDS_POD=$(kubectl get pod -n openhands-dev -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')

# 检查环境变量
kubectl exec -n openhands-dev $OPENHANDS_POD -- env | grep DOCKER

# 预期输出：
# DOCKER_HOST=tcp://docker-dind.openhands-dev.svc.cluster.local:2375
# DOCKER_TLS_CERTDIR=

# 测试 Docker 连接
kubectl exec -n openhands-dev $OPENHANDS_POD -- docker version

# 预期输出：Docker 版本信息
```

### Step 5: 访问 OpenHands

```bash
# 方式 1：Port Forward
kubectl port-forward -n openhands-dev svc/openhands 3000:3000

# 浏览器访问：http://localhost:3000

# 方式 2：NodePort（已在 values-k8s-production.yaml 中配置）
# 获取 Node IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# 访问：http://$NODE_IP:30030
```

---

## ✅ 验证部署

### 1. 创建测试会话

1. 打开浏览器访问 OpenHands
2. 创建新会话
3. 输入测试任务

### 2. 查看 DinD 中的容器

```bash
# 获取 DinD Pod 名称
DIND_POD=$(kubectl get pod -n openhands-dev -l app=docker-dind -o jsonpath='{.items[0].metadata.name}')

# 查看运行中的容器
kubectl exec -n openhands-dev $DIND_POD -- docker ps

# 预期输出（创建会话后）：
# CONTAINER ID   IMAGE                                        COMMAND     CREATED
# abc123          harbor.inspur.local/open-hands/runtime:...  "/bin/bash"   2 min ago
```

### 3. 查看容器日志

```bash
# 查看特定容器的日志
kubectl exec -n openhands-dev $DIND_POD -- docker logs <container-id>
```

---

## 🔧 关键配置说明

### values-k8s-production.yaml 修改

| 配置项 | 修改前 | 修改后 | 说明 |
|--------|--------|--------|------|
| `runtime` | `kubernetes` | `docker` | 使用 Docker Runtime |
| `containerEnv.DOCKER_HOST` | 无 | `tcp://docker-dind.openhands-dev.svc.cluster.local:2375` | DinD 服务地址 |
| `containerEnv.DOCKER_TLS_CERTDIR` | 无 | `""` | 禁用 TLS |
| `dockerSocket.enabled` | `false` | `false` | 禁用本地 socket（远程 DinD） |
| `privileged` | `false` | `false` | 不需要特权模式（远程 DinD） |

### DinD Service 地址格式

```
格式：<service-name>.<namespace>.svc.cluster.local:<port>

您的配置：
  Service Name: docker-dind
  Namespace: openhands-dev
  Port: 2375

完整地址：docker-dind.openhands-dev.svc.cluster.local:2375
```

---

## 📊 监控和调试

### 查看 OpenHands 日志

```bash
# 实时查看日志
kubectl logs -f -n openhands-dev -l app.kubernetes.io/name=openhands

# 查看沙盒相关日志
kubectl logs -n openhands-dev -l app.kubernetes.io/name=openhands | grep -i sandbox
```

### 查看 DinD 日志

```bash
# 实时查看 DinD 日志
kubectl logs -f -n openhands-dev -l app=docker-dind

# 查看 DinD 资源使用
kubectl top pod -n openhands-dev -l app=docker-dind
```

### 网络调试

```bash
# 从 OpenHands Pod 测试网络连接
kubectl exec -n openhands-dev $OPENHANDS_POD -- nc -zv docker-dind.openhands-dev.svc.cluster.local 2375

# 测试 DNS 解析
kubectl exec -n openhands-dev $OPENHANDS_POD -- nslookup docker-dind.openhands-dev.svc.cluster.local
```

---

## 🔍 故障排查

### 问题 1：OpenHands 无法连接 DinD

**症状**：
```
SandboxError: Sandbox failed to start within 120s
```

**解决**：
```bash
# 1. 检查 DinD Service
kubectl get svc docker-dind -n openhands-dev

# 2. 检查 DinD Pods
kubectl get pods -n openhands-dev -l app=docker-dind

# 3. 测试连通性
kubectl exec -n openhands-dev $OPENHANDS_POD -- docker version

# 4. 查看 OpenHands 日志
kubectl logs -n openhands-dev $OPENHANDS_POD | grep -i docker
```

### 问题 2：环境变量未生效

**症状**：
```bash
kubectl exec -n openhands-dev $OPENHANDS_POD -- env | grep DOCKER
# (无输出)
```

**解决**：
```bash
# 重新部署
helm upgrade openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace openhands-dev

# 等待 Pod 重建
kubectl rollout status deployment/openhands -n openhands-dev
```

### 问题 3：容器创建缓慢

**症状**：
```
Sandbox failed to start within 120s
```

**解决**：
```bash
# 增加 DinD 资源
kubectl edit deployment docker-dind -n openhands-dev

# 或编辑 values-k8s-production.yaml
# 增加 kubernetes.runtimeResources 限制
```

---

## 📝 相关文档

- [完整部署指南](../DEPLOY_WITH_DIND.md)
- [DinD 部署指南](../DIND_DEPLOYMENT_GUIDE.md)
- [K8s 沙盒说明](../OPENHANDS_K8S_SANDBOX_GUIDE.md)
- [快速开始](../QUICKSTART_DIND.md)

---

## 🎯 总结

### 修改内容

1. ✅ `values-k8s-production.yaml` - 修改为 Docker Runtime + DinD 连接
2. ✅ `values-dind.yaml` - 新增独立 DinD 配置
3. ✅ `values-k8s-production-with-dind.yaml` - 新增生产环境 DinD 配置

### 部署命令

```bash
# 推荐：使用修改后的生产配置
helm upgrade openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace openhands-dev \
  --reuse-values

# 设置 API Key
helm upgrade openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace openhands-dev \
  --set openhands.llm.apiKey="sk-your-api-key-here" \
  --set openhands.llm.model=gpt-4o \
  --reuse-values
```

### 验证成功

- ✅ OpenHands Pod 运行正常
- ✅ 环境变量 `DOCKER_HOST` 已设置
- ✅ `docker version` 命令成功
- ✅ 创建会话后可以在 DinD 中看到容器

### 预期效果

- ✅ 每个会话创建独立的 Docker 容器
- ✅ 在 DinD Pod 中使用 `docker ps` 可以看到所有会话容器
- ✅ 不再为每个会话创建 Kubernetes Pod
- ✅ 容器级别的资源隔离

---

## 📞 支持

如有问题，请查看：
- GitHub Issues: [https://github.com/OpenHands/OpenHands/issues](https://github.com/OpenHands/OpenHands/issues)
- 文档: [https://docs.openhands.dev](https://docs.openhands.dev)
