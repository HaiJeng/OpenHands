# PVC 分离架构实现 - 变更总结

## 变更概述

将 OpenHands Helm chart 的持久化存储架构从单一 PVC 改为独立的 data/workspace PVC 双卷架构。

## 修改的文件列表

1. **values.yaml** - 拆分 persistence 配置为 data/workspace
2. **templates/_helpers.tpl** - 新增独立的 PVC 名称 helper 函数
3. **templates/pvc.yaml** - 创建两个独立的 PVC 资源
4. **templates/deployment.yaml** - 条件化 volume 挂载
5. **values-dev-example.yaml** - 更新开发环境示例
6. **values-production-example.yaml** - 更新生产环境示例
7. **README.md** - 更新配置文档
8. **MIGRATION_GUIDE.md** - 新增迁移指南
9. **PVC_ARCHITECTURE.md** - 新增架构说明

## 核心变更

### 配置结构变更

```yaml
# 旧配置
persistence:
  enabled: true
  size: 10Gi

# 新配置
persistence:
  enabled: true
  data:
    enabled: true
    size: 5Gi
  workspace:
    enabled: true
    size: 10Gi
```

### PVC 资源变更

```yaml
# 之前：1 个 PVC (10Gi)
openhands-data

# 之后：2 个独立 PVC
openhands-data (5Gi)
openhands-workspace (10Gi)
```

## 新功能

1. **独立管理**：data 和 workspace 可独立配置
2. **可选启用**：可单独禁用某个 PVC
3. **现有引用**：支持引用现有 PVC
4. **灵活存储类**：可为不同数据选择不同存储
5. **向后兼容**：通过引用同一 PVC 保持兼容

## 向后兼容性

用户可继续使用单一 PVC：

```yaml
persistence:
  data:
    existingClaim: my-shared-pvc
  workspace:
    existingClaim: my-shared-pvc
```

## 优势

- 成本优化：按需分配存储
- 性能提升：选择最优存储类型
- 数据隔离：应用与代码分离
- 备份灵活：不同备份策略
- 高可用：支持 ReadWriteMany

详细说明见：
- [PVC_ARCHITECTURE.md](./PVC_ARCHITECTURE.md) - 架构设计
- [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md) - 迁移步骤
- [README.md](./README.md) - 使用文档
