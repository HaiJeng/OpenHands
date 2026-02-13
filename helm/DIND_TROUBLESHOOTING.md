# OpenHands DinD 部署故障排查指南

## 问题概述

**症状**: OpenHands Web 界面可以访问，但当创建对话时，沙箱（action execution server）启动失败

**错误日志**:
```
Sandbox server not running: http://localhost:33013 : All connection attempts failed
SandboxError: 500: Sandbox entered error state: oh-agent-server-xxxxxxxxxxxx
```

## 根本原因

在 DinD (Docker-in-Docker) 模式下，OpenHands 需要连接到远程 DinD 服务，并在其中启动 agent-server 容器。agent-server 容器启动失败导致会话无法创建。

## 常见原因及解决方案

### 1. Docker 连接失败

**症状**: OpenHands Pod 无法连接到 DinD 服务

**检查步骤**:
```bash
# 1. 检查 DinD Service 是否存在
kubectl get svc docker-dind -n openhands-dev

# 2. 从 OpenHands Pod 测试连接
OPENHANDS_POD=$(kubectl get pod -n openhands-dev -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n openhands-dev $OPENHANDS_POD -- sh -c "nc -zv docker-dind.openhands-dev.svc.cluster.local 2375"

# 3. 检查环境变量
kubectl exec -n openhands-dev $OPENHANDS_POD -- env | grep DOCKER_HOST
kubectl exec -n openhands-dev $OPENHANDS_POD -- env | grep DOCKER_TLS_CERTDIR
```

**解决方案**:
- 确保 DinD Service 正常运行
- 确保 `DOCKER_HOST=tcp://docker-dind.openhands-dev.svc.cluster.local:2375`
- 确保 `DOCKER_TLS_CERTDIR=""`（空字符串，禁用 TLS）

### 2. 镜像拉取失败

**症状**: agent-server 镜像无法拉取

**检查步骤**:
```bash
# 1. 检查镜像是否存在于 DinD
DIND_POD=$(kubectl get pod -n openhands-dev -l app=docker-dind -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n openhands-dev $DIND_POD -- docker images | grep agent-server

# 2. 手动拉取镜像测试
kubectl exec -n openhands-dev $DIND_POD -- docker pull harbor.inspur.local/open-hands/agent-server:1.10.0-python
```

**解决方案**:

**方案 A**: 预拉取镜像到 DinD
```bash
# 进入 DinD Pod
kubectl exec -it -n openhands-dev $DIND_POD -- sh

# 拉取所需镜像
docker pull harbor.inspur.local/open-hands/agent-server:1.10.0-python
docker pull harbor.inspur.local/open-hands/runtime:main-nikolaik
docker pull harbor.inspur.local/open-hands/openhands:1.3.6
```

**方案 B**: 为 DinD Pod 配置镜像拉取密钥
```yaml
# 在 DinD 部署配置中添加
apiVersion: v1
kind: Secret
metadata:
  name: harbor-registry-secret
  namespace: openhands-dev
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: docker-dind
  namespace: openhands-dev
spec:
  template:
    spec:
      imagePullSecrets:
        - name: harbor-registry-secret
```

### 3. 存储卷问题

**症状**: agent-server 容器无法挂载工作区或数据卷

**检查步骤**:
```bash
# 检查 PVC 状态
kubectl get pvc -n openhands-dev

# 检查 DinD Pod 的卷挂载
kubectl describe pod -n openhands-dev $DIND_POD | grep -A 10 "Volumes:"
```

**解决方案**:
- 确保 PVC 已正确创建并绑定
- 确保 StorageClass 可用（如 "rbd"）
- 确保 DinD Pod 有权限挂载共享卷

### 4. 网络策略限制

**症状**: Pod 之间无法通信

**检查步骤**:
```bash
# 检查网络策略
kubectl get networkpolicy -n openhands-dev
```

**解决方案**:
- 删除或修改限制性网络策略
- 确保 OpenHands Pod 可以访问 DinD Service 的 2375 端口

### 5. 资源不足

**症状**: agent-server 容器因资源限制启动失败

**检查步骤**:
```bash
# 检查节点资源
kubectl top nodes

# 检查 Pod 资源使用
kubectl top pods -n openhands-dev
```

**解决方案**:
```yaml
# 增加 OpenHands 和 DinD Pod 的资源限制
resources:
  limits:
    cpu: 4
    memory: 8Gi
  requests:
    cpu: 2
    memory: 4Gi
```

## 快速诊断脚本

使用提供的诊断脚本进行全面检查：

```bash
cd /workspace/project/OpenHands/helm
chmod +x diagnose-dind-issue.sh
./diagnose-dind-issue.sh
```

## 手动验证步骤

### 步骤 1: 验证 DinD 服务
```bash
# 检查 DinD Pod
DIND_POD=$(kubectl get pod -n openhands-dev -l app=docker-dind -o jsonpath='{.items[0].metadata.name}')
kubectl get pod -n openhands-dev $DIND_POD

# 查看 DinD 日志
kubectl logs -n openhands-dev $DIND_POD --tail 50
```

### 步骤 2: 验证 Docker 连接
```bash
# 从 OpenHands Pod 测试
OPENHANDS_POD=$(kubectl get pod -n openhands-dev -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n openhands-dev $OPENHANDS_POD -- docker version
kubectl exec -n openhands-dev $OPENHANDS_POD -- docker ps
```

### 步骤 3: 验证容器创建
```bash
# 创建测试容器
kubectl exec -n openhands-dev $OPENHANDS_POD -- docker run --rm hello-world

# 创建 agent-server 测试容器
kubectl exec -n openhands-dev $OPENHANDS_POD -- docker run -d \
  --name test-agent-server \
  -e SANDBOX_DISABLE_EXTRA_HOSTS=1 \
  harbor.inspur.local/open-hands/agent-server:1.10.0-python

# 检查容器状态
kubectl exec -n openhands-dev $OPENHANDS_POD -- docker ps -a | grep test-agent-server

# 查看容器日志
kubectl exec -n openhands-dev $OPENHANDS_POD -- docker logs test-agent-server

# 清理
kubectl exec -n openhands-dev $OPENHANDS_POD -- docker rm -f test-agent-server
```

## 配置修复建议

### 修复 1: 确保 DinD 配置正确

检查 DinD Service 端口配置：
```yaml
apiVersion: v1
kind: Service
metadata:
  name: docker-dind
  namespace: openhands-dev
spec:
  ports:
    - port: 2375        # ✅ 确保端口为 2375
      targetPort: 2375
      protocol: TCP
```

### 修复 2: 确保 OpenHands 环境变量正确

在 values-dind.yaml 或 values-k8s-production.yaml 中：
```yaml
openhands:
  sandbox:
    runtime: docker
    containerEnv:
      - name: DOCKER_HOST
        value: "tcp://docker-dind.openhands-dev.svc.cluster.local:2375"
      - name: DOCKER_TLS_CERTDIR
        value: ""
      - name: SANDBOX_DISABLE_EXTRA_HOSTS
        value: "1"
```

### 修复 3: 预拉取镜像（推荐）

在部署 OpenHands 之前，先拉取所需镜像到 DinD：

```bash
# 创建预拉取脚本
cat > /tmp/preload-images.sh << 'EOF'
#!/bin/bash
DIND_POD=$(kubectl get pod -n openhands-dev -l app=docker-dind -o jsonpath='{.items[0].metadata.name}')

echo "预拉取镜像到 DinD..."

kubectl exec -n openhands-dev $DIND_POD -- docker pull harbor.inspur.local/open-hands/agent-server:1.10.0-python
kubectl exec -n openhands-dev $DIND_POD -- docker pull harbor.inspur.local/open-hands/runtime:main-nikolaik
kubectl exec -n openhands-dev $DIND_POD -- docker pull harbor.inspur.local/open-hands/openhands:1.3.6
kubectl exec -n openhands-dev $DIND_POD -- docker pull harbor.inspur.local/open-hands/uv:latest

echo "✓ 镜像预拉取完成"
EOF

chmod +x /tmp/preload-images.sh
/tmp/preload-images.sh
```

## 日志查看命令

```bash
# OpenHands 日志
kubectl logs -f -n openhands-dev $OPENHANDS_POD

# DinD 日志
kubectl logs -f -n openhands-dev $DIND_POD

# 查看 DinD 中运行的容器
kubectl exec -n openhands-dev $DIND_POD -- docker ps -a

# 查看特定 agent-server 容器日志
CONTAINER_ID=$(kubectl exec -n openhands-dev $DIND_POD -- docker ps -a | grep agent-server | awk '{print $1}')
kubectl exec -n openhands-dev $DIND_POD -- docker logs $CONTAINER_ID
```

## 验证修复

完成修复后，验证部署：

```bash
# 1. 创建新对话
# 通过 Web UI 或 API 创建新对话

# 2. 检查 agent-server 容器
kubectl exec -n openhands-dev $DIND_POD -- docker ps | grep agent-server

# 3. 检查 OpenHands 日志
kubectl logs -n openhands-dev $OPENHANDS_POD --tail 50

# 4. 应该看到类似以下日志（成功）:
# INFO:openhands.app_server.sandbox.docker_sandbox_service:Sandbox is running: http://localhost:33013
# INFO:openhands.app_server.app_conversation:Conversation started successfully
```

## 常见错误代码

| 错误代码 | 含义 | 解决方案 |
|---------|------|---------|
| 500 | Sandbox 进入错误状态 | 检查 agent-server 容器日志 |
| `All connection attempts failed` | 无法连接到沙箱 | 检查 DOCKER_HOST 和网络 |
| `Image pull failed` | 镜像拉取失败 | 配置镜像密钥或预拉取 |
| `No such file or directory` | 卷挂载失败 | 检查 PVC 配置 |
| `permission denied` | 权限问题 | 检查 Pod 安全上下文 |

## 参考文档

- 部署指南: `/workspace/project/OpenHands/helm/openhands/README_DIND_DEPLOYMENT.md`
- 命令速查: `/workspace/project/OpenHands/helm/OPENHANDS_HELM_COMMANDS.md`
- K8S Runtime 指南: `/workspace/project/OpenHands/helm/K8S_RUNTIME_GUIDE.md`
