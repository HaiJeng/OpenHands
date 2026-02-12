# PVC 迁移指南

本文档说明如何从单一 PVC 配置迁移到独立的 data/workspace PVC 配置。

## 迁移背景

从版本 v0.0.2 开始，OpenHands Helm chart 支持独立的 PVC 配置：
- **data PVC**：存储应用配置、对话历史等（默认 5Gi）
- **workspace PVC**：存储用户代码和项目（默认 10Gi）

## 迁移前的注意事项

⚠️ **重要**：迁移过程中会停止服务，请确保在维护窗口内进行操作。

## 迁移步骤

### 步骤 1：备份现有数据

```bash
# 1. 获取当前 Pod 名称
POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')

# 2. 创建备份目录
kubectl exec -it $POD_NAME -- mkdir -p /tmp/backup

# 3. 备份数据
kubectl exec $POD_NAME -- tar czf /tmp/backup/openhands-backup.tar.gz /.openhands /opt/workspace_base

# 4. 复制备份到本地
kubectl cp $POD_NAME:/tmp/backup/openhands-backup.tar.gz ./openhands-backup.tar.gz

# 5. 验证备份文件
ls -lh openhands-backup.tar.gz
```

### 步骤 2：卸载现有部署

```bash
# 1. 卸载 Helm release（保留 PVC）
helm uninstall openhands

# 2. 等待 Pod 完全终止
kubectl wait --for=delete pod -l app.kubernetes.io/name=openhands --timeout=60s

# 3. 查看现有 PVC
kubectl get pvc | grep openhands
```

你应该看到类似输出：
```
NAME                    STATUS   VOLUME                   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
openhands-data           Bound    pvc-1234567890abc      10Gi       RWO            standard       30d
```

### 步骤 3：创建新的 PVC

#### 选项 A：全新部署（推荐用于新环境）

```bash
# 直接使用新配置安装，新 PVC 会自动创建
helm install openhands ./openhands \
  --set openhands.llm.apiKey=your-api-key \
  --set persistence.data.size=5Gi \
  --set persistence.workspace.size=10Gi
```

#### 选项 B：迁移现有数据（生产环境）

```bash
# 1. 创建临时 Pod 用于数据迁移
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: openhands-migration
spec:
  containers:
  - name: migration
    image: busybox
    command: ['sh', '-c', 'sleep 3600']
    volumeMounts:
    - name: old-pvc
      mountPath: /old-data
    - name: new-data
      mountPath: /new-data
    - name: new-workspace
      mountPath: /new-workspace
  volumes:
  - name: old-pvc
    persistentVolumeClaim:
      claimName: openhands-data
  - name: new-data
    persistentVolumeClaim:
      claimName: openhands-new-data
  - name: new-workspace
    persistentVolumeClaim:
      claimName: openhands-new-workspace
EOF

# 2. 等待 Pod 就绪
kubectl wait --for=condition=ready pod/openhands-migration --timeout=60s

# 3. 上传备份文件
kubectl cp openhands-backup.tar.gz openhands-migration:/tmp/

# 4. 在 Pod 中解压并分离数据
kubectl exec openhands-migration -- sh -c "
  cd /tmp && tar xzf openhands-backup.tar.gz
  cp -r old-data/.openhands/* /new-data/
  cp -r old-data/opt/workspace_base/* /new-workspace/
  ls -la /new-data/
  ls -la /new-workspace/
"

# 5. 验证数据迁移成功
kubectl exec openhands-migration -- du -sh /new-data /new-workspace

# 6. 删除迁移 Pod
kubectl delete pod openhands-migration
```

### 步骤 4：使用新 PVC 部署

```bash
# 创建新的 values 文件
cat > migration-values.yaml <<EOF
persistence:
  data:
    existingClaim: openhands-new-data
    enabled: true
  workspace:
    existingClaim: openhands-new-workspace
    enabled: true

openhands:
  llm:
    apiKey: your-api-key
    model: gpt-4o
EOF

# 使用新 PVC 部署
helm install openhands ./openhands -f migration-values.yaml

# 等待 Pod 就绪
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=openhands --timeout=120s

# 验证部署
kubectl get pods -l app.kubernetes.io/name=openhands
kubectl logs -l app.kubernetes.io/name=openhands --tail=20
```

### 步骤 5：验证新部署

```bash
# 1. 获取新 Pod 名称
NEW_POD=$(kubectl get pods -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')

# 2. 检查数据目录
kubectl exec $NEW_POD -- ls -la /.openhands
kubectl exec $NEW_POD -- ls -la /opt/workspace_base

# 3. 访问应用（如果配置了 Ingress）
curl -I https://openhands.example.com
```

### 步骤 6：清理旧资源

```bash
# 确认新部署正常后，删除旧的 PVC
kubectl delete pvc openhands-data

# 删除备份文件（可选）
rm openhands-backup.tar.gz
```

## 回滚方案

如果迁移失败，可以快速回滚：

```bash
# 1. 卸载新部署
helm uninstall openhands

# 2. 恢复使用旧 PVC
cat > rollback-values.yaml <<EOF
persistence:
  enabled: true
  # 使用旧的单 PVC 配置兼容模式
  data:
    existingClaim: openhands-data
    enabled: true
  workspace:
    existingClaim: openhands-data
    enabled: true

openhands:
  llm:
    apiKey: your-api-key
EOF

# 3. 重新部署
helm install openhands ./openhands -f rollback-values.yaml
```

## 配置对比

### 旧配置（单一 PVC）

```yaml
persistence:
  enabled: true
  existingClaim: ""          # 使用自动创建的 PVC
  storageClass: ""
  accessMode: ReadWriteOnce
  size: 10Gi                # 所有数据共享 10Gi
```

**创建的 PVC**：
- `openhands-data` (10Gi) - 同时挂载到 `/.openhands` 和 `/opt/workspace_base`

### 新配置（独立 PVC）

```yaml
persistence:
  enabled: true
  data:
    enabled: true
    existingClaim: ""         # 或使用现有 PVC
    storageClass: ""
    accessMode: ReadWriteOnce
    size: 5Gi              # 应用数据独立 5Gi
  workspace:
    enabled: true
    existingClaim: ""         # 或使用现有 PVC
    storageClass: ""
    accessMode: ReadWriteOnce
    size: 10Gi             # 工作区数据独立 10Gi
```

**创建的 PVC**：
- `openhands-data` (5Gi) - 挂载到 `/.openhands`
- `openhands-workspace` (10Gi) - 挂载到 `/opt/workspace_base`

## 新功能：禁用特定 PVC

新配置允许单独启用/禁用某个 PVC：

```yaml
persistence:
  enabled: true
  data:
    enabled: false           # 禁用数据持久化（使用临时存储）
  workspace:
    enabled: true           # 只持久化工作区
    size: 20Gi
```

## 常见问题

### Q1: 必须迁移吗？

**A**: 不是必须的。如果你想继续使用单一 PVC，可以使用以下配置：

```yaml
persistence:
  data:
    existingClaim: my-shared-pvc
    enabled: true
  workspace:
    existingClaim: my-shared-pvc  # 两个 volume 引用同一个 PVC
    enabled: true
```

### Q2: 迁移需要多长时间？

**A**: 取决于数据量：
- 小于 1GB：约 5-10 分钟
- 1-10GB：约 10-30 分钟
- 大于 10GB：建议预先测试

### Q3: 迁移期间服务会中断吗？

**A**: 是的，迁移期间服务会停止。建议：
1. 提前通知用户
2. 选择低峰时段进行
3. 准备好回滚方案

### Q4: 可以在线迁移吗？

**A**: 当前不支持在线迁移。未来版本可能会考虑使用 ROX（ReadOnlyMany）进行在线备份。

## 获取帮助

如果遇到问题：

1. 查看日志：`kubectl logs -l app.kubernetes.io/name=openhands`
2. 检查事件：`kubectl get events --sort-by='.lastTimestamp'`
3. GitHub Issues: https://github.com/OpenHands/OpenHands/issues
4. 文档: https://docs.openhands.dev

## 最佳实践

1. **始终备份**：迁移前务必备份数据
2. **测试环境先行**：先在测试环境验证迁移流程
3. **监控资源**：迁移过程中监控 PVC 和 Pod 状态
4. **分阶段迁移**：如果是大规模部署，考虑分批迁移
5. **文档记录**：记录迁移过程中的配置和操作
