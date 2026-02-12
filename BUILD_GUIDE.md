# 镜像重新构建指南

## 问题描述

修改了 `containers/app/entrypoint.sh` 后，需要重新构建 Docker 镜像以包含新的代码。

## 构建方式

### 方案 1：手动触发 GitHub Actions（推荐）

这是最简单的方式，使用 GitHub Actions 自动构建和推送镜像。

#### 步骤：

1. **访问 GitHub Actions 页面**
   ```
   https://github.com/HaiJeng/OpenHands/actions/workflows/ghcr-build.yml
   ```

2. **点击 "Run workflow" 按钮**
   - 在左侧选择 "Docker" workflow
   - 点击 "Run workflow" 按钮
   - 在 "Reason" 输入框中填写：`Fix entrypoint root permission check`
   - 点击绿色 "Run workflow" 按钮确认

3. **等待构建完成**
   - 构建时间约 15-30 分钟
   - 构建完成后会生成新的镜像 tag
   - 镜像会推送到 `ghcr.io/openhands/openhands`

4. **获取新镜像**
   ```bash
   docker pull ghcr.io/openhands/openhands:latest
   ```

### 方案 2：本地构建镜像

如果您想在本地构建和测试镜像。

#### 前置要求

```bash
# 检查 Docker 是否运行
docker info

# 登录到 GHCR（如果需要）
echo $GITHUB_TOKEN | docker login ghcr.io -u openhands --password-stdin
```

#### 构建命令

```bash
cd /workspace/project/OpenHands

# 构建 app 镜像
docker build \
  -f containers/app/Dockerfile \
  -t ghcr.io/openhands/openhands:local-build \
  --build-arg OPENHANDS_BUILD_VERSION=dev \
  .

# 构建完成后，您可以：
# 1. 本地测试
docker run --rm -p 3000:3000 ghcr.io/openhands/openhands:local-build

# 2. 推送到 registry（可选）
docker push ghcr.io/openhands/openhands:local-build
```

### 方案 3：等待自动构建（如果合并到 main）

如果您将修改合并到 `main` 分支，GitHub Actions 会自动触发构建。

```bash
# 1. 合并 PR 到 main
# 2. 等待 GitHub Actions 自动构建
# 3. 新镜像会自动推送到 ghcr.io/openhands/openhands:latest
```

## Helm Chart 镜像配置

### 使用 GitHub Actions 构建的镜像

```yaml
# values.yaml（默认配置）
image:
  repository: ghcr.io/openhands/openhands
  tag: latest  # 或者具体的版本号
  pullPolicy: IfNotPresent
```

### 使用本地构建的镜像

```yaml
# values.yaml（本地测试）
image:
  repository: ghcr.io/openhands/openhands
  tag: local-build  # 使用本地构建的 tag
  pullPolicy: Never  # 使用本地镜像

# 或使用本地镜像
image:
  repository: openhands/openhands
  tag: latest
  pullPolicy: Never
```

## 验证镜像是否包含修复

### 1. 检查 entrypoint.sh

```bash
# 使用本地构建的镜像
docker run --rm ghcr.io/openhands/openhands:local-build \
  cat /app/entrypoint.sh | head -20

# 应该看到：文件开头不再包含 "if [ "$(id -u)" -ne 0 ]" 检查
```

### 2. 测试容器启动

```bash
# 测试以非 root 用户运行
docker run --rm -p 3000:3000 \
  -e OPENHANDS_LLM_API_KEY=test \
  -e OPENHANDS_LLM_MODEL=gpt-4o \
  ghcr.io/openhands/openhands:local-build

# 应该成功启动，不再显示 "must run as root" 错误
```

### 3. 在 Kubernetes 中测试

```bash
# 使用 Helm 部署测试
helm install openhands-test ./helm/openhands \
  --set image.tag=local-build \
  --set openhands.llm.apiKey=test-key \
  --set openhands.llm.model=gpt-4o

# 查看日志
kubectl logs -l app.kubernetes.io/name=openhands-test --tail=50

# 应该看到正常启动，没有权限错误
```

## 更新 Kubernetes 部署

### 场景 1：使用 GitHub Actions 最新镜像

```bash
# 1. 等待 GitHub Actions 构建完成
# 2. 更新 Helm release
helm upgrade openhands ./helm/openhands \
  --reuse-values \
  --set image.tag=latest  # 或具体版本号

# 3. 强制重新拉取镜像
kubectl delete pod -l app.kubernetes.io/name=openhands
```

### 场景 2：使用本地构建的镜像

```bash
# 1. 本地构建并推送到 registry
docker build -f containers/app/Dockerfile -t ghcr.io/openhands/openhands:test .
docker push ghcr.io/openhands/openhands:test

# 2. 更新 Helm release 使用新镜像
helm upgrade openhands ./helm/openhands \
  --set image.tag=test \
  --reuse-values

# 3. 验证部署
kubectl get pods -l app.kubernetes.io/name=openhands
kubectl logs -l app.kubernetes.io/name=openhands --tail=20
```

## 故障排查

### 问题：镜像拉取失败

```bash
# 检查镜像是否存在
docker pull ghcr.io/openhands/openhands:latest

# 如果使用本地镜像，确保镜像存在
docker images | grep openhands
```

### 问题：Pod 仍然显示权限错误

```bash
# 1. 确认使用的是新镜像
kubectl describe pod -l app.kubernetes.io/name=openhands | grep Image

# 2. 检查 entrypoint.sh 是否真的被修改
kubectl exec -it <pod-name> -- cat /app/entrypoint.sh | head -20

# 3. 查看 Pod 安全上下文
kubectl describe pod -l app.kubernetes.io/name=openhands | grep -A 5 "Security Context"
```

### 问题：Helm 部署失败

```bash
# 1. 检查 Helm chart 语法
helm lint ./openhands

# 2. Dry-run 测试
helm upgrade openhands ./openhands --dry-run --debug

# 3. 检查 values.yaml 配置
grep -A 5 "image:" ./openhands/values.yaml
```

## 推荐流程

### 开发测试流程

```bash
# 1. 本地构建快速测试
cd /workspace/project/OpenHands
docker build -f containers/app/Dockerfile -t openhands:test .

# 2. 本地运行测试
docker run --rm -p 3000:3000 openhands:test

# 3. 确认修复有效
# 4. 提交并推送到 GitHub
git push origin add-helm-chart

# 5. 触发 GitHub Actions 构建
# 在 GitHub Actions 页面手动触发

# 6. 等待构建完成并更新 Kubernetes
```

### 生产部署流程

```bash
# 1. 合并 PR 到 main 分支
# 2. 等待 GitHub Actions 自动构建（约 15-30 分钟）
# 3. 确认新镜像已推送到 GHCR
# 4. 更新 values.yaml 中的 image.tag（如果使用特定版本）
# 5. 执行 helm upgrade
helm upgrade openhands ./openhands --reuse-values

# 6. 验证部署状态
kubectl rollout status deployment/openhands
```

## 相关链接

- **GitHub Actions**: https://github.com/HaiJeng/OpenHands/actions
- **Docker Workflow**: https://github.com/HaiJeng/OpenHands/blob/main/.github/workflows/ghcr-build.yml
- **Helm Chart**: https://github.com/HaiJeng/OpenHands/tree/add-helm-chart/helm/openhands

## 注意事项

1. **镜像标签**：使用 `latest` tag 会在每次构建时更新，生产环境建议使用固定版本号
2. **拉取策略**：`IfNotPresent` 会使用本地缓存，如果镜像更新需要删除旧 Pod 或设置 `Always`
3. **构建时间**：首次构建可能需要 30+ 分钟，后续构建会使用缓存更快
4. **权限**：确保推送到 GHCR 的权限正确（需要 GitHub Token）
