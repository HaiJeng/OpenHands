# OpenHands NodePort 访问指南

## 🎯 NodePort 配置

### 配置说明

```yaml
service:
  type: NodePort              # ✅ 使用 NodePort
  port: 3000                 # Service Port (容器端口）
  nodePort: 30030            # ✅ NodePort (外部访问端口, 30000-32767)
  sessionAffinity: ClientIP   # 推荐：同一客户端连接同一 Pod
```

### 工作原理

```
外部访问 (http://<NodeIP>:30030)
    ↓
NodePort Service (30030 → 3000)
    ↓
OpenHands Pod (Port 3000)
    ↓
Web UI
```

## 🚀 部署步骤

### 步骤 1：设置变量

```bash
# 命名空间
export NAMESPACE="openhands"

# 生成密钥
export JWT_SECRET=$(openssl rand -base64 32 | tr -d '/+=')
export SECRET_KEY=$(openssl rand -base64 32 | tr -d '/+=')

# LLM API Key（替换为实际密钥）
export LLM_API_KEY="sk-your-actual-api-key"

# 验证
echo "JWT: ${JWT_SECRET:0:8}..."
echo "KEY: ${SECRET_KEY:0:8}..."
echo "API: ${LLM_API_KEY:0:15}..."
```

### 步骤 2：部署

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

### 步骤 3：验证部署

```bash
# 检查 Pod
kubectl get pods -n $NAMESPACE

# 检查 Service（应该显示 NodePort）
kubectl get svc -n $NAMESPACE

# 检查 NodePort
kubectl get svc openhands -n $NAMESPACE -o yaml | grep -A 5 "type: NodePort"
```

## 🌐 访问 OpenHands

### 方式 1：通过节点 IP 访问（推荐）

#### 获取节点 IP

```bash
# 获取第一个节点的 IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# 或获取主机名
NODE_HOST=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="Hostname")].address}')

echo "Node IP: $NODE_IP"
echo "Node Host: $NODE_HOST"
```

#### 访问地址

```
http://<NODE_IP>:30030
```

**示例**：
- 如果节点 IP 是 `192.168.1.100`
- 访问地址：`http://192.168.1.100:30030`

### 方式 2：通过节点主机名访问

```bash
# 获取节点主机名
NODE_HOST=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="Hostname")].address}')

# 访问
echo "访问地址: http://$NODE_HOST:30030"
```

### 方式 3：通过多个节点访问

```bash
# 获取所有节点 IP
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'

# 可以通过任何节点 IP:30030 访问
```

### 方式 4：本地测试（从集群外）

如果您的机器可以直接访问节点：

```bash
# 测试连接
curl -I http://<NODE_IP>:30030

# 或在浏览器打开
# http://<NODE_IP>:30030
```

## 🔍 验证访问

### 检查 Service

```bash
# 查看 Service 详情
kubectl describe svc openhands -n $NAMESPACE

# 应该看到：
# Type: NodePort
# Port: <unset> 3000/TCP
# NodePort: 30030/TCP
```

### 检查 Endpoints

```bash
# 检查 Pod 是否正常
kubectl get endpoints openhands -n $NAMESPACE

# 应该看到 Pod IP，如：
# ENDPOINTS              10.244.1.5:3000
```

### 测试内部访问

```bash
# 从 Pod 内部测试
POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -n $NAMESPACE -- curl -I http://openhands:3000

# 应该返回 200 OK
```

### 测试外部访问

```bash
# 从集群外测试（将 NODE_IP 替换为实际 IP）
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
curl -I http://$NODE_IP:30030

# 应该返回 200 OK
```

## 🛠️ 获取访问信息脚本

创建一个便捷脚本来获取访问信息：

```bash
cat > get-access-info.sh <<'EOF'
#!/bin/bash
NAMESPACE="openhands"

echo "======================================"
echo "OpenHands 访问信息"
echo "======================================"

# 获取 Service
echo ""
echo "Service 信息:"
kubectl get svc openhands -n $NAMESPACE

# 获取 NodePort
NODE_PORT=$(kubectl get svc openhands -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
echo ""
echo "NodePort: $NODE_PORT"

# 获取节点 IP
echo ""
echo "节点 IP 地址:"
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' | tr ' ' '\n' | nl

# 获取访问地址
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo ""
echo "======================================"
echo "访问地址:"
echo "http://$NODE_IP:$NODE_PORT"
echo "======================================"
echo ""

# 检查 Pod 状态
echo "Pod 状态:"
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=openhands
echo ""
EOF

chmod +x get-access-info.sh

# 运行脚本
./get-access-info.sh
```

## 🔧 故障排除

### 问题 1：无法通过 NodePort 访问

#### 检查 1：Service 状态

```bash
kubectl get svc openhands -n $NAMESPACE

# 确保 Type 是 NodePort
```

#### 检查 2：NodePort 范围

```bash
# 查看 NodePort 范围
kubectl get svc openhands -n $NAMESPACE -o yaml | grep nodePort

# 确保 nodePort 在 30000-32767 范围内
```

#### 检查 3：防火墙

```bash
# 检查防火墙是否开放 30030 端口
sudo firewall-cmd --list-ports  # RHEL/CentOS
sudo ufw status  # Ubuntu

# 如果需要开放端口
sudo firewall-cmd --permanent --add-port=30030/tcp  # RHEL/CentOS
sudo ufw allow 30030/tcp  # Ubuntu
```

#### 检查 4：节点网络

```bash
# 确保可以从外部访问节点
ping <NODE_IP>

# 测试端口
telnet <NODE_IP> 30030
nc -zv <NODE_IP> 30030
```

### 问题 2：Service 显示但无法访问

#### 检查 Endpoints

```bash
kubectl get endpoints openhands -n $NAMESPACE

# 如果没有 endpoints，说明 Pod 有问题
# 检查 Pod 状态
kubectl get pods -n $NAMESPACE
```

#### 检查 Pod 日志

```bash
POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD -n $NAMESPACE
```

### 问题 3：Pod 正常但无法访问

#### 检查 Pod 端口

```bash
# 进入 Pod 测试
POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -n $NAMESPACE -- netstat -tlnp | grep 3000

# 应该看到 0.0.0.0:3000
```

#### 检查 Service Selector

```bash
kubectl get svc openhands -n $NAMESPACE -o yaml | grep -A 5 selector

# 确保 selector 正确匹配 Pod
kubectl get pods -n $NAMESPACE --show-labels
```

### 问题 4：浏览器无法访问

#### 检查浏览器控制台

- 打开浏览器开发者工具 (F12)
- 查看 Console 和 Network 标签
- 检查是否有错误信息

#### 检查代理设置

- 如果使用代理，确保代理配置正确
- 或尝试直接访问节点 IP

#### 尝试其他浏览器

- 某些浏览器可能有安全限制
- 尝试使用 Chrome/Firefox/Edge

## 📊 监控 NodePort 访问

### 查看连接数

```bash
# 查看服务连接
kubectl get svc openhands -n $NAMESPACE -o yaml | grep -i endpoint

# 查看连接统计（如果已安装 metrics-server）
kubectl top pods -n $NAMESPACE
kubectl top nodes
```

### 查看访问日志

```bash
# 查看 OpenHands 访问日志
POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')
kubectl logs -f $POD -n $NAMESPACE | grep -i "GET\|POST"
```

## 🔐 安全建议

### 生产环境

1. **使用 Ingress + TLS** ⭐ 推荐
   - 更安全的 HTTPS 访问
   - 更好的负载均衡
   - 支持域名和证书管理

2. **网络策略**
   - 限制哪些 IP 可以访问 NodePort
   - 使用防火墙规则

3. **认证**
   - 配置 OpenHands 的认证机制
   - 使用 JWT_SECRET

### 开发/测试环境

1. **NodePort 可以接受**
   - 快速访问
   - 方便测试

2. **限制访问**
   - 使用防火墙限制来源 IP
   - 仅内网访问

## 🔄 修改 NodePort

如果需要更改 NodePort：

### 临时修改

```bash
kubectl edit svc openhands -n $NAMESPACE

# 找到 nodePort 字段，修改为其他值 (30000-32767)
# 保存后自动生效
```

### 永久修改

修改 `values-k8s-production.yaml`：

```yaml
service:
  type: NodePort
  port: 3000
  nodePort: 30031  # 修改为其他端口
```

然后重新部署：

```bash
cd /workspace/project/OpenHands/helm

helm upgrade openhands ./openhands \
  -f ./openhands/values.yaml \
  -f ./openhands/values-k8s-production.yaml \
  --namespace $NAMESPACE \
  --reuse-values \
  --wait
```

## 📋 完整示例

### 部署并获取访问信息

```bash
#!/bin/bash
set -e

# 设置变量
NAMESPACE="openhands"
JWT_SECRET=$(openssl rand -base 32 | tr -d '/+=')
SECRET_KEY=$(openssl rand -base 32 | tr -d '/+=')
LLM_API_KEY="sk-your-actual-api-key"

# 部署
cd /workspace/project/OpenHands/helm

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

# 等待 Pod 就绪
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=openhands \
  -n $NAMESPACE \
  --timeout=300s

# 获取访问信息
echo ""
echo "======================================"
echo "部署成功！"
echo "======================================"

NODE_PORT=$(kubectl get svc openhands -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo ""
echo "访问地址: http://$NODE_IP:$NODE_PORT"
echo ""
echo "等待约 30 秒让应用完全启动..."
echo "======================================"
```

## 🎉 完成！

现在您可以通过 NodePort 访问 OpenHands 了：

```
http://<NODE_IP>:30030
```

**示例**：
- 节点 IP: `192.168.1.100`
- 访问地址: `http://192.168.1.100:30030`

## 📚 相关文档

- [README.md](./README.md) - 总览文档
- [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - 完整部署指南
- [K8S_RUNTIME_GUIDE.md](./K8S_RUNTIME_GUIDE.md) - Kubernetes Runtime 指南

---

**需要帮助？**

```bash
# 查看日志
kubectl logs -f deployment/openhands -n $NAMESPACE

# 查看 Service
kubectl describe svc openhands -n $NAMESPACE

# 查看 Pod
kubectl describe pod -l app.kubernetes.io/name=openhands -n $NAMESPACE
```
