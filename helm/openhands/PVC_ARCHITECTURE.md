# PVC 架构更新说明

## 更新概述

从 v0.0.2 版本开始，OpenHands Helm chart 将数据持久化从单一 PVC 拆分为两个独立的 PVC：
- **data PVC**：存储应用配置、对话历史、文件存储等
- **workspace PVC**：存储用户代码、项目文件等

## 更改原因

### 1. 更灵活的资源管理
- **独立扩展**：可以根据实际需求独立调整 data 和 workspace 的存储大小
- **成本优化**：避免为数据量小的应用分配过多存储
- **性能优化**：可以为不同的数据类型选择不同的存储类（如 SSD vs HDD）

### 2. 更好的数据隔离
- **数据分离**：应用数据和用户代码物理隔离，提高安全性
- **备份策略**：可以为不同的数据类型制定不同的备份策略
- **迁移便利**：可以单独迁移某个 PVC 而不影响其他数据

### 3. 支持高可用场景
- **ReadWriteMany 支持**：可以为多副本部署配置共享存储
- **故障隔离**：某个 PVC 的故障不会影响另一个 PVC
- **灵活的访问模式**：可以为 data 和 workspace 配置不同的访问模式

## 技术变更

### 之前（单一 PVC）

```yaml
# values.yaml
persistence:
  enabled: true
  size: 10Gi              # 所有数据共享
  storageClass: ""
  accessMode: ReadWriteOnce
  
# deployment.yaml 中的挂载
volumes:
- name: data
  persistentVolumeClaim:
    claimName: openhands-data
- name: workspace
  persistentVolumeClaim:
    claimName: openhands-data  # 同一个 PVC
```

**资源清单**：
- 1 个 PVC：`openhands-data` (10Gi)
- 2 个 volume 引用同一个 PVC

### 之后（独立 PVC）

```yaml
# values.yaml
persistence:
  enabled: true
  data:
    enabled: true
    size: 5Gi              # 应用数据独立
    storageClass: ""
    accessMode: ReadWriteOnce
    existingClaim: ""
  workspace:
    enabled: true
    size: 10Gi             # 工作区数据独立
    storageClass: ""
    accessMode: ReadWriteOnce
    existingClaim: ""
    
# deployment.yaml 中的挂载
volumes:
- name: data
  persistentVolumeClaim:
    claimName: openhands-data
- name: workspace
  persistentVolumeClaim:
    claimName: openhands-workspace  # 独立的 PVC
```

**资源清单**：
- 2 个 PVC：
  - `openhands-data` (5Gi)
  - `openhands-workspace` (10Gi)
- 2 个 volume 各自引用独立的 PVC

## 新增功能

### 1. 可选的 PVC 启用/禁用

```yaml
persistence:
  enabled: true
  data:
    enabled: false           # 禁用数据持久化
  workspace:
    enabled: true           # 只持久化工作区
    size: 20Gi
```

**使用场景**：
- 开发环境：只持久化工作区，数据使用临时存储
- 测试环境：只持久化配置，工作区每次重新创建
- 成本优化：为不需要持久化的数据节省存储成本

### 2. 现有 PVC 引用

```yaml
persistence:
  data:
    enabled: true
    existingClaim: my-data-pvc
  workspace:
    enabled: true
    existingClaim: my-workspace-pvc
```

**使用场景**：
- 已有存储基础设施的环境
- 跨命名空间共享存储
- 特殊的备份和恢复需求

### 3. 不同的存储类配置

```yaml
persistence:
  data:
    storageClass: fast-ssd       # 数据使用 SSD
    size: 5Gi
  workspace:
    storageClass: standard-hdd    # 工作区使用 HDD
    size: 100Gi
```

**使用场景**：
- 成本优化：为不同的数据选择性价比最高的存储
- 性能优化：为频繁访问的数据使用高速存储
- 容量规划：为大数据量使用大容量存储

## 向后兼容性

### 继续使用单一 PVC

如果你希望保持单一 PVC 的配置，可以这样做：

```yaml
persistence:
  enabled: true
  data:
    enabled: true
    existingClaim: my-shared-pvc
  workspace:
    enabled: true
    existingClaim: my-shared-pvc  # 引用同一个 PVC
```

这样会创建 2 个 volume，但它们引用同一个 PVC。

### 旧 values.yaml 配置兼容性

如果你使用旧的配置格式（单一 PVC），升级到新版本时需要更新配置：

```yaml
# 旧配置（不再支持）
persistence:
  enabled: true
  size: 10Gi
  
# 新配置（必需）
persistence:
  enabled: true
  data:
    size: 5Gi
  workspace:
    size: 10Gi
```

## 迁移指南

详细的迁移步骤请参考 [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md)。

快速迁移命令：

```bash
# 1. 备份现有数据
POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -- tar czf /tmp/backup.tar.gz /.openhands /opt/workspace_base
kubectl cp $POD_NAME:/tmp/backup.tar.gz ./openhands-backup.tar.gz

# 2. 卸载现有部署
helm uninstall openhands

# 3. 使用新配置重新部署
helm install openhands ./openhands \
  --set persistence.data.size=5Gi \
  --set persistence.workspace.size=10Gi \
  --set openhands.llm.apiKey=your-api-key

# 4. 恢复数据（如需要）
# 详细步骤见 MIGRATION_GUIDE.md
```

## 配置示例

### 开发环境

```yaml
persistence:
  data:
    enabled: false          # 使用临时存储
  workspace:
    enabled: true
    size: 5Gi            # 较小的工作区
```

### 测试环境

```yaml
persistence:
  data:
    enabled: true
    size: 2Gi            # 小数据卷
  workspace:
    enabled: false         # 每次重新创建
```

### 生产环境（小规模）

```yaml
persistence:
  data:
    enabled: true
    size: 10Gi
    storageClass: fast-ssd
    accessMode: ReadWriteOnce
  workspace:
    enabled: true
    size: 50Gi
    storageClass: standard
    accessMode: ReadWriteOnce
```

### 生产环境（大规模 + HPA）

```yaml
persistence:
  data:
    enabled: true
    size: 20Gi
    storageClass: nfs-storage
    accessMode: ReadWriteMany   # 支持多副本
  workspace:
    enabled: true
    size: 200Gi
    storageClass: nfs-storage
    accessMode: ReadWriteMany   # 支持多副本

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
```

## 常见问题

### Q: 这个改动会破坏现有部署吗？

**A**: 不会。新版本通过 `existingClaim` 参数支持向后兼容。但你必须更新 values.yaml 配置格式。

### Q: 是否必须立即迁移？

**A**: 不是必须的。你可以继续使用现有配置，但建议在下一次维护窗口时迁移到新架构以获得更好的灵活性。

### Q: 数据会丢失吗？

**A**: 只要正确执行迁移步骤（备份 → 迁移 → 验证），数据不会丢失。详细步骤见 [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md)。

### Q: 性能会受影响吗？

**A**: 不会。实际上，独立 PVC 可能会带来性能提升，因为：
- 可以为不同数据选择不同的存储类
- 减少了单一 PVC 的 I/O 竞争
- 更好的存储规划

## 模板文件变更

### 1. `_helpers.tpl`

新增两个 helper 函数：

```yaml
{{- define "openhands.dataPvcName" -}}
{{- if .Values.persistence.data.existingClaim }}
{{- .Values.persistence.data.existingClaim }}
{{- else }}
{{- printf "%s-data" (include "openhands.fullname" .) }}
{{- end }}
{{- end }}

{{- define "openhands.workspacePvcName" -}}
{{- if .Values.persistence.workspace.existingClaim }}
{{- .Values.persistence.workspace.existingClaim }}
{{- else }}
{{- printf "%s-workspace" (include "openhands.fullname" .) }}
{{- end }}
{{- end }}
```

### 2. `pvc.yaml`

拆分为创建两个独立的 PVC 资源：

```yaml
# Data PVC
{{- if and .Values.persistence.enabled .Values.persistence.data.enabled (not .Values.persistence.data.existingClaim) }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "openhands.dataPvcName" . }}
  labels:
    app.kubernetes.io/component: data
...
{{- end }}

# Workspace PVC
{{- if and .Values.persistence.enabled .Values.persistence.workspace.enabled (not .Values.persistence.workspace.existingClaim) }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "openhands.workspacePvcName" . }}
  labels:
    app.kubernetes.io/component: workspace
...
{{- end }}
```

### 3. `deployment.yaml`

条件化挂载和引用：

```yaml
volumeMounts:
{{- if .Values.persistence.data.enabled }}
- name: data
  mountPath: {{ .Values.openhands.fileStore.path }}
{{- end }}
{{- if .Values.persistence.workspace.enabled }}
- name: workspace
  mountPath: {{ .Values.openhands.workspace.base }}
{{- end }}

volumes:
{{- if .Values.persistence.data.enabled }}
- name: data
  persistentVolumeClaim:
    claimName: {{ include "openhands.dataPvcName" . }}
{{- end }}
{{- if .Values.persistence.workspace.enabled }}
- name: workspace
  persistentVolumeClaim:
    claimName: {{ include "openhands.workspacePvcName" . }}
{{- end }}
```

## 测试验证

部署后验证配置：

```bash
# 1. 检查 PVC 是否正确创建
kubectl get pvc | grep openhands

# 预期输出：
# openhands-data           Bound    pvc-xxx    5Gi   RWO   standard   1m
# openhands-workspace       Bound    pvc-yyy    10Gi  RWO   standard   1m

# 2. 检查 Pod 是否正确挂载
kubectl describe pod -l app.kubernetes.io/name=openhands | grep -A 5 "Mounts:"

# 3. 进入 Pod 验证挂载点
POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=openhands -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -- df -h | grep -E "Filesystem|/.openhands|/opt/workspace_base"

# 4. 测试数据写入
kubectl exec $POD_NAME -- sh -c "echo 'test' > /.openhands/test.txt"
kubectl exec $POD_NAME -- sh -c "echo 'test' > /opt/workspace_base/test.txt"
kubectl exec $POD_NAME -- cat /.openhands/test.txt
kubectl exec $POD_NAME -- cat /opt/workspace_base/test.txt
```

## 支持和反馈

如果遇到问题或有改进建议：

- **GitHub Issues**: https://github.com/OpenHands/OpenHands/issues
- **文档**: https://docs.openhands.dev
- **社区**: https://github.com/OpenHands/OpenHands/blob/main/COMMUNITY.md

## 版本历史

- **v0.0.2** (2024-01): 引入独立 PVC 架构
- **v0.0.1** 及之前: 使用单一 PVC
