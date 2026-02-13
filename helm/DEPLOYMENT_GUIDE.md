# OpenHands Kubernetes Runtime 部署指南

## 🎯 部署前检查

### 1. 检查 Kubernetes 集群

```bash
# 检查集群连接
kubectl cluster-info

# 检查节点状态
kubectl get nodes

# 检查 StorageClass（PVC需要）
kubectl get storageclass

# 如果没有合适的 StorageClass，需要先创建
```

### 2. 检查 Helm

```bash
# 检查 Helm 版本
helm version

# 如果没有安装，先安装
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 3. 准备配置文件

配置文件位置：
- `helm/openhands/values.yaml` - 基础配置
- `helm/openhands/values-k8s-production.yaml` - Kubernetes runtime 配置
- `/workspace/my-values.yaml` - 您的自定义配置

## 🚀 方式1：直接部署（推荐）

### 步骤1：设置环境变量

```bash
# 设置命名空间
export NAMESPACE="openhands"

# 生成安全密钥
export JWT_SECRET=$(openssl rand -base64 32 | tr -d '/+=')
export SECRET_KEY=$(openssl rand -base64 32 | tr -d '/+=')

# 设置 LLM API Key（替换为实际密钥）
export LLM_API_KEY="sk-your-actual-api-key-here"

# 验证变量
echo "JWT_SECRET: ${JWT_SECRET:0:10}..."
echo "SECRET_KEY: ${SECRET_KEY:0:10}..."
echo "LLM_API_KEY: ${LLM_API_KEY:0:10}..."
```

### 步骤2：创建命名空间

```bash
# 创建命名空间
kubectl create namespace $NAMESPACE

# 如果命名空间已存在，忽略错误
```

### 步骤3：部署 OpenHands

```bash
cd /workspace/project/OpenHands/helm

# 部署
helm install openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace $NAMESPACE \
  --create-namespace \
  --set openhands.llm.apiKey="$LLM_API_KEY" \
  --set openhands.jwtSecret="$JWT_SECRET" \
  --set openhands.secretKey="$SECRET_KEY" \
  --timeout 10m \
  --wait
```

**参数说明**：
- `-f ./openhands/values.yaml` - 基础配置
- `-f ./openhands/values-k8s-production.yaml` - Kubernetes runtime 配置
- `--namespace $NAMESPACE` - 部署命名空间
- `--create-namespace` - 自动创建命名空间
- `--set openhands.llm.apiKey` - LLM API Key
- `--set openhands.jwtSecret` - JWT 密钥
- `--set openhands.secretKey` - 应用密钥
- `--timeout 10m` - 部署超时时间
- `--wait` - 等待部署完成

### 步骤4：验证部署

```bash
# 等待 Pod 就绪
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=openhands \
  -n $NAMESPACE \
  --timeout=300s

# 检查 Pod 状态
kubectl get pods -n $NAMESPACE

# 检查 Service
kubectl get svc -n $NAMESPACE

# 检查 PVC
kubectl get pvc -n $NAMESPACE

# 查看日志（应该没有错误）
kubectl logs -f deployment/openhands -n $NAMESPACE
```

### 步骤5：访问 OpenHands

#### 方式A：NodePort（推荐用于测试）

```bash
# 获取 NodePort
NODE_PORT=$(kubectl get svc openhands -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')

# 获取节点 IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')

# 访问
echo "访问地址: http://$NODE_IP:$NODE_PORT"
```

#### 方式B：Port Forward（本地测试）

```bash
# 转发端口
kubectl port-forward svc/openhands 3000:3000 -n $NAMESPACE

# 访问
# http://localhost:3000
```

#### 方式C：Ingress（生产环境推荐）

需要先配置 Ingress，见下方。

## 🔧 方式2：使用自定义配置文件

如果您想使用 `/workspace/my-values.yaml`：

```bash
cd /workspace/project/OpenHands/helm

# 合并您的配置
helm install openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  -f /workspace/my-values.yaml \
  --namespace $NAMESPACE \
  --create-namespace \
  --set openhands.llm.apiKey="$LLM_API_KEY" \
  --set openhands.jwtSecret="$JWT_SECRET" \
  --set openhands.secretKey="$SECRET_KEY" \
  --timeout 10m \
  --wait
```

## 🔄 升级部署

如果已部署，需要升级：

```bash
cd /workspace/project/OpenHands/helm

# 升级
helm upgrade openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace $NAMESPACE \
  --set openhands.llm.apiKey="$LLM_API_KEY" \
  --reuse-values \
  --wait
```

## 📊 部署后检查

### 1. 检查 OpenHands Pod

```bash
# 获取 Pod 名称
POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')

# 查看 Pod 状态
kubectl describe pod $POD -n $NAMESPACE

# 查看日志
kubectl logs -f $POD -n $NAMESPACE
```

### 2. 检查 Runtime Pod（Kubernetes runtime 会创建）

```bash
# 查看所有 Runtime Pod
kubectl get pods -A | grep openhands

# Runtime Pod 的命名模式: openhands-xxx-runtime-xxx
```

### 3. 测试功能

```bash
# 进入 OpenHands Pod
kubectl exec -it $POD -n $NAMESPACE -- bash

# 测试基本命令
python --version
node --version

# 查看环境变量
env | grep -i openhands

# 退出
exit
```

### 4. 检查网络

```bash
# 测试 DNS 解析
kubectl exec $POD -n $NAMESPACE -- nslookup github.com

# 测试外网连接
kubectl exec $POD -n $NAMESPACE -- curl -I https://api.github.com
```

## 🐛 故障排除

### 问题1：Pod 无法启动

```bash
# 查看 Pod 事件
kubectl describe pod <pod-name> -n $NAMESPACE

# 常见问题：
# - ImagePullBackOff: 镜像拉取失败 → 检查 imagePullSecrets
# - CrashLoopBackOff: 容器启动失败 → 查看日志
# - Pending: PVC 绑定失败 → 检查 StorageClass
```

### 问题2：镜像拉取失败

```bash
# 创建镜像拉取密钥
kubectl create secret docker-registry harbor-secret \
  --docker-server=harbor.inspur.local \
  --docker-username=<your-username> \
  --docker-password=<your-password> \
  --docker-email=<your-email> \
  -n $NAMESPACE

# 在 values 中配置
# imagePullSecrets:
#   - name: harbor-secret
```

### 问题3：PVC 绑定失败

```bash
# 检查 StorageClass
kubectl get storageclass

# 查看 PVC 事件
kubectl describe pvc -n $NAMESPACE

# 如果使用动态存储，确保 StorageClass 正确
# 如果使用静态 PV，需要手动创建 PV
```

### 问题4：无法访问

```bash
# 检查 Service
kubectl get svc -n $NAMESPACE

# 检查 Endpoint（Pod 是否正常）
kubectl get endpoints openhands -n $NAMESPACE

# 测试 Service 内部访问
kubectl exec $POD -n $NAMESPACE -- curl http://openhands.$NAMESPACE.svc.cluster.local:3000
```

## 🔐 配置 Ingress（生产环境）

### 1. 使用 NGINX Ingress Controller

```bash
# 创建 Ingress 文件
cat > openhands-ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: openhands
  namespace: $NAMESPACE
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - host: openhands.example.com  # 替换为您的域名
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: openhands
            port:
              number: 3000
EOF

# 应用 Ingress
kubectl apply -f openhands-ingress.yaml
```

### 2. 配置 TLS/HTTPS

```bash
# 安装 cert-manager（如果未安装）
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# 创建 ClusterIssuer
cat > letencrypt-issuer.yaml <<EOF
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

kubectl apply -f letencrypt-issuer.yaml

# 更新 Ingress 配置添加 TLS
cat > openhands-ingress-tls.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: openhands
  namespace: $NAMESPACE
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - openhands.example.com
    secretName: openhands-tls
  rules:
  - host: openhands.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: openhands
            port:
              number: 3000
EOF

kubectl apply -f openhands-ingress-tls.yaml
```

## 📝 配置验证清单

部署前验证：

- [ ] Kubernetes 集群正常
- [ ] Helm 已安装
- [ ] StorageClass 可用
- [ ] 镜像仓库可访问（harbor.inspur.local）
- [ ] LLM API Key 已设置
- [ ] JWT_SECRET 和 SECRET_KEY 已生成
- [ ] 命名空间已创建
- [ ] 资源配置合理（CPU、内存）
- [ ] 存储容量足够（data: 5Gi, workspace: 10Gi）
- [ ] 网络配置正确（Service/Ingress）

部署后验证：

- [ ] OpenHands Pod 状态为 Running
- [ ] 日志无错误信息
- [ ] Service 正常创建
- [ ] PVC 绑定成功
- [ ] 可通过 NodePort/Ingress 访问
- [ ] Runtime Pod 正常创建（当创建对话时）

## 🎉 完成！

部署成功后，您就可以通过以下方式访问 OpenHands：

- **NodePort**: `http://<NodeIP>:<NodePort>`
- **Port Forward**: `http://localhost:3000`
- **Ingress**: `https://openhands.example.com`

开始使用 OpenHands 进行 AI 辅助编程！

## 📖 参考文档

- [K8S_RUNTIME_GUIDE.md](./K8S_RUNTIME_GUIDE.md) - Kubernetes runtime 完整指南
- [values-k8s-production.yaml](./openhands/values-k8s-production.yaml) - 生产配置文件
- [openhands/DEPLOYMENT_GUIDE.md](./openhands/DEPLOYMENT_GUIDE.md) - 通用部署指南

---

**需要帮助？** 查看日志：`kubectl logs -f deployment/openhands -n $NAMESPACE`
