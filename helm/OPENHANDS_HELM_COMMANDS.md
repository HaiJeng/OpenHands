# OpenHands Helm 部署命令速查表

## 🚀 完整部署流程

### Step 1: 部署 OpenHands（使用 DinD）

```bash
cd /workspace/project/OpenHands/helm

# 方式 1：升级现有部署（推荐）
helm upgrade openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace openhands-dev \
  --reuse-values

# 方式 2：全新安装
helm install openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace openhands-dev

# 方式 3：使用专用 DinD 配置文件
helm upgrade openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  -f ./openhands/values-k8s-production-with-dind.yaml \
  --namespace openhands-dev \
  --reuse-values
```

### Step 2: 设置 LLM API Key

```bash
# 方式 1：通过命令行设置（推荐）
helm upgrade openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace openhands-dev \
  --set openhands.llm.apiKey="sk-your-api-key-here" \
  --set openhands.llm.model=gpt-4o \
  --set openhands.llm.baseURL="https://api.openai.com/v1" \
  --reuse-values

# 方式 2：直接编辑配置文件
vim /workspace/project/OpenHands/helm/openhands/values-k8s-production.yaml
# 修改第 30 行：apiKey: "sk-your-api-key-here"

# 然后重新部署
helm upgrade openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace openhands-dev \
  --reuse-values
```

### Step 3: 验证部署

```bash
# 1. 检查 Pod 状态
kubectl get pods -n openhands-dev -l app.kubernetes.io/name=openhands

# 2. 等待 Pod 就绪
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=openhands \
  -n openhands-dev \
  --timeout=300s

# 3. 获取 Pod 名称
OPENHANDS_POD=$(kubectl get pod -n openhands-dev -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')

# 4. 验证环境变量
kubectl exec -n openhands-dev $OPENHANDS_POD -- env | grep DOCKER

# 5. 测试 Docker 连接
kubectl exec -n openhands-dev $OPENHANDS_POD -- docker version

# 6. 测试创建容器
kubectl exec -n openhands-dev $OPENHANDS_POD -- docker run --rm hello-world
```

### Step 4: 访问 OpenHands

```bash
# 方式 1：Port Forward（本地开发）
kubectl port-forward -n openhands-dev svc/openhands 3000:3000
# 浏览器访问：http://localhost:3000

# 方式 2：NodePort（生产环境）
# NodePort 已在 values-k8s-production.yaml 中配置为 30030
# 获取节点 IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
# 浏览器访问：http://$NODE_IP:30030

# 方式 3：Ingress（需要配置）
# 在 values-k8s-production.yaml 中启用 ingress
helm upgrade openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace openhands-dev \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.hosts[0].host=openhands.example.com \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix \
  --reuse-values
```

---

## 🔧 常用维护命令

### 查看日志

```bash
# 实时查看 OpenHands 日志
kubectl logs -f -n openhands-dev -l app.kubernetes.io/name=openhands

# 查看沙盒相关日志
kubectl logs -n openhands-dev -l app.kubernetes.io/name=openhands | grep -i sandbox

# 查看最近 100 行日志
kubectl logs -n openhands-dev -l app.kubernetes.io/name=openhands --tail=100
```

### 查看 DinD 中的容器

```bash
# 获取 DinD Pod
DIND_POD=$(kubectl get pod -n openhands-dev -l app=docker-dind -o jsonpath='{.items[0].metadata.name}')

# 查看运行中的容器
kubectl exec -n openhands-dev $DIND_POD -- docker ps

# 查看所有容器（包括停止的）
kubectl exec -n openhands-dev $DIND_POD -- docker ps -a

# 查看容器日志
kubectl exec -n openhands-dev $DIND_POD -- docker logs <container-id>

# 进入容器
kubectl exec -n openhands-dev $DIND_POD -- docker exec -it <container-id> /bin/bash
```

### 资源监控

```bash
# 查看 Pod 资源使用
kubectl top pods -n openhands-dev

# 查看 DinD 资源使用
kubectl top pods -n openhands-dev -l app=docker-dind

# 查看 PVC 使用情况
kubectl get pvc -n openhands-dev
```

### 重启服务

```bash
# 重启 OpenHands
kubectl rollout restart deployment/openhands -n openhands-dev

# 重启 DinD
kubectl rollout restart deployment/docker-dind -n openhands-dev

# 查看 rollout 状态
kubectl rollout status deployment/openhands -n openhands-dev
```

### 卸载

```bash
# 完全卸载 OpenHands
helm uninstall openhands -n openhands-dev

# 删除 PVC（可选，会删除数据）
kubectl get pvc -n openhands-dev
kubectl delete pvc <pvc-name> -n openhands-dev
```

---

## 📝 快速配置模板

### 修改镜像仓库

```bash
# 使用您的私有 Harbor 仓库
helm upgrade openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace openhands-dev \
  --set image.repository=harbor.example.com/open-hands/openhands \
  --set image.tag=v1.3.4 \
  --set image.runtime.repository=harbor.example.com/open-hands/runtime \
  --set image.runtime.tag=main-nikolaik \
  --set image.agentServer.repository=harbor.example.com/open-hands/agent-server \
  --set image.agentServer.tag=v1.10.0-python \
  --reuse-values
```

### 配置资源限制

```bash
# 调整资源限制
helm upgrade openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace openhands-dev \
  --set resources.requests.cpu=500m \
  --set resources.requests.memory=1Gi \
  --set resources.limits.cpu=2 \
  --set resources.limits.memory=2Gi \
  --reuse-values
```

### 配置持久化存储

```bash
# 使用现有 PVC
helm upgrade openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace openhands-dev \
  --set persistence.data.existingClaim=openhands-data-pvc \
  --set persistence.workspace.existingClaim=openhands-workspace-pvc \
  --reuse-values

# 修改存储类
helm upgrade openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace openhands-dev \
  --set persistence.data.storageClass=fast-ssd \
  --set persistence.workspace.storageClass=fast-ssd \
  --reuse-values
```

### 配置 NodePort

```bash
# 修改 NodePort
helm upgrade openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace openhands-dev \
  --set service.type=NodePort \
  --set service.nodePort=30030 \
  --reuse-values
```

---

## 🎯 验证部署成功的检查清单

- [ ] OpenHands Pod 状态为 `Running`
- [ ] 环境变量 `DOCKER_HOST` 已设置
- [ ] `docker version` 命令成功
- [ ] `docker run hello-world` 成功
- [ ] 可以访问 OpenHands Web UI
- [ ] 创建会话后可以在 DinD 中看到容器
- [ ] 日志中没有错误信息

```bash
# 一键验证脚本
echo "=== 检查 Pod 状态 ==="
kubectl get pods -n openhands-dev -l app.kubernetes.io/name=openhands

echo ""
echo "=== 检查环境变量 ==="
OPENHANDS_POD=$(kubectl get pod -n openhands-dev -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n openhands-dev $OPENHANDS_POD -- env | grep DOCKER

echo ""
echo "=== 测试 Docker 连接 ==="
kubectl exec -n openhands-dev $OPENHANDS_POD -- docker version | head -5

echo ""
echo "=== 检查 DinD 容器数量 ==="
DIND_POD=$(kubectl get pod -n openhands-dev -l app=docker-dind -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n openhands-dev $DIND_POD -- docker ps | wc -l

echo ""
echo "✅ 部署验证完成！"
```

---

## 📚 相关文档

- [完整部署指南](./README_DIND_DEPLOYMENT.md)
- [DinD 部署指南](/workspace/DIND_DEPLOYMENT_GUIDE.md)
- [快速开始](/workspace/QUICKSTART_DIND.md)
- [K8s 沙盒说明](/workspace/OPENHANDS_K8S_SANDBOX_GUIDE.md)

---

## 💡 提示

1. **首次部署**：建议先使用 `--dry-run --debug` 参数查看生成的配置
   ```bash
   helm upgrade openhands ./openhands \
     -f ./openhands/values.yaml \
     -f ./openhands/values-k8s-production.yaml \
     --namespace openhands-dev \
     --dry-run --debug
   ```

2. **查看生成的配置**：
   ```bash
   helm get values openhands -n openhands-dev
   ```

3. **查看部署历史**：
   ```bash
   helm history openhands -n openhands-dev
   ```

4. **回滚到上一个版本**：
   ```bash
   helm rollback openhands -n openhands-dev
   ```

5. **保存配置到文件**：
   ```bash
   helm get values openhands -n openhands-dev > my-values.yaml
   ```
