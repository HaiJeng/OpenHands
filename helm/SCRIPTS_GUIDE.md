# OpenHands Helm 诊断和修复脚本指南

本文档说明 `/helm` 目录中的所有诊断和修复脚本。

## 📋 脚本概览

### 诊断脚本（Diagnostic Scripts）

#### 1. `debug-dind-deployment.sh`
**用途**: DinD 部署基本故障排查

**功能**:
- 检查 OpenHands Pod 环境变量（DOCKER_HOST, DOCKER_TLS_CERTDIR）
- 测试 Docker 连接
- 检查已有镜像
- 检查 DinD 中的会话容器
- 测试镜像拉取
- 查看 OpenHands 最新日志
- 检查网络连接

**使用方法**:
```bash
./debug-dind-deployment.sh
```

---

#### 2. `diagnose-agent-network.sh` ⭐ 推荐
**用途**: agent-server 容器网络诊断（详细）

**功能**:
- 获取 agent-server 容器信息
- **检查端口绑定（关键）** - 检查 33013 端口是否正确绑定
- 检查容器内部监听端口
- 检查容器网络配置（IP, 网络模式）
- 测试网络连接（从多个角度）
- 查看 agent-server 日志
- 提供针对性的修复建议

**使用方法**:
```bash
./diagnose-agent-network.sh
```

**输出示例**:
```
[2/6] 检查端口绑定（关键）...
容器端口映射:
8000/tcp -> 0.0.0.0:33013

✗ 端口 33013 未绑定到 Docker 主机
这是主要问题！

可能原因:
  1. agent-server 监听在 127.0.0.1:33013（仅本地）
  2. 应该监听 0.0.0.0:33013（所有接口）
```

---

#### 3. `test-agent-connection.sh`
**用途**: 测试从 OpenHands Pod 到 agent-server 的连接

**功能**:
- 测试从 DinD Pod 访问 localhost:33013（映射后端口）
- 测试从 DinD Pod 访问容器 IP:8000（直接访问）
- 测试从 OpenHands Pod 访问 DinD Pod IP:33013（跨 Pod 访问）
- 测试从 OpenHands Pod 访问 localhost:33013（当前配置）
- 提供解决方案建议

**使用方法**:
```bash
./test-agent-connection.sh
```

---

#### 4. `test-dind-connectivity.sh` ⭐ 推荐
**用途**: DinD 连接性全面测试（最新）

**功能**:
- 测试从 OpenHands Pod 访问 DinD Pod IP:33013
- 测试从 OpenHands Pod 访问 DinD Service IP:33013
- 测试从 OpenHands Pod 访问容器 IP:8000
- 测试从 DinD Pod 内部访问 localhost:33013
- **根据测试结果推荐最佳解决方案**:
  - 如果 DinD Pod IP 可访问: 使用 DinD Pod IP（推荐，永久）
  - 如果 DinD Service IP 可访问: 使用 Kubernetes Service IP
  - 如果容器 IP 可访问: 使用 socat 端口转发
  - 如果 DinD 内 localhost 可访问: 使用代理（复杂）

**使用方法**:
```bash
./test-dind-connectivity.sh
```

**输出示例**:
```
[测试 1] 从 OpenHands Pod 测试 DinD Pod IP:33013
✓ 可以连接到 172.11.x.x:33013
→ 这是最佳解决方案！使用 DinD Pod IP

========================================
推荐解决方案
========================================

✅ 方案 1: 使用 DinD Pod IP（推荐）

在 OpenHands 配置中设置环境变量：
  SANDBOX_HOST=172.11.x.x
  SANDBOX_PORT=33013

或修改 OpenHands 启动参数，连接到：
  http://172.11.x.x:33013
```

---

### 修复脚本（Fix Scripts）

#### 1. `socat-fix.sh`
**用途**: 使用 socat 在 OpenHands Pod 内创建端口转发（临时修复）

**工作原理**:
```
OpenHands Pod 内部:
  localhost:33013 ──socat──> 172.17.0.2:8000
  (期望连接)              (实际 agent-server)
```

**功能**:
- 检查 socat 安装（如果需要则安装）
- 停止旧的 socat 进程
- 启动端口转发: `localhost:33013 -> 容器IP:8000`
- 测试连接
- 提供日志查看命令

**使用方法**:
```bash
./socat-fix.sh
```

**限制**:
- ❌ 临时修复，OpenHands Pod 重启后失效
- ✅ 快速，不需要修改配置

---

### 文档

#### 1. `DIND_TROUBLESHOOTING.md`
**用途**: 完整的 DinD 部署故障排查指南

**内容**:
- 问题概述和根本原因
- 常见原因及解决方案
- 快速诊断步骤
- 手动验证步骤
- 配置修复建议
- 日志查看命令
- 常见错误代码
- 参考文档

---

## 🚀 使用流程

### 推荐的诊断流程

```
开始
  ↓
1. 运行 debug-dind-deployment.sh
   → 基本检查，确认 DinD 运行正常
  ↓
2. 运行 test-dind-connectivity.sh ⭐
   → 测试所有可能的连接方式
   → 获得最佳解决方案建议
  ↓
3. 根据测试结果选择方案:
   ↓
   ├─ 如果 DinD Pod IP 可访问 → 修改配置使用 DinD Pod IP ✅
   ├─ 如果 DinD Service IP 可访问 → 修改配置使用 Service IP ✅
   ├─ 如果容器 IP 可访问 → 运行 socat-fix.sh ⚠️
   └─ 如果都不行 → 运行 diagnose-agent-network.sh 详细诊断
  ↓
4. 验证修复:
   → 运行 test-dind-connectivity.sh 确认
   → 通过 Web UI 创建新会话测试
```

### 快速修复流程

如果您已经知道问题，可以直接：

```bash
# 方案 A: 使用 DinD Pod IP（推荐，永久）
./test-dind-connectivity.sh
# 根据输出修改 OpenHands 配置

# 方案 B: 使用 socat 临时修复
./socat-fix.sh
# 注意: Pod 重启后失效

# 方案 C: 重启 OpenHands Pod
kubectl delete pod -n openhands-dev openhands-77f96867-vc682
# 自动重启并重新创建 agent-server
```

---

## 🎯 常见问题

### 问题 1: 端口 33013 未绑定

**症状**:
```
✗ 端口 33013 未绑定到 Docker 主机
```

**原因**: agent-server 容器端口映射配置错误

**解决方案**:
1. 先运行 `./test-dind-connectivity.sh`
2. 如果 DinD Pod IP 可访问，修改配置使用 DinD Pod IP
3. 如果不行，运行 `./socat-fix.sh` 临时修复

---

### 问题 2: OpenHands 无法连接到 localhost:33013

**症状**:
```
✗ OpenHands Pod 无法连接到 localhost:33013
```

**原因**: DinD 架构中的网络隔离问题

**解决方案**:
```bash
# 步骤 1: 测试连接
./test-dind-connectivity.sh

# 步骤 2: 根据输出选择方案
# - 如果 DinD Pod IP 可访问: 使用 DinD Pod IP
# - 如果容器 IP 可访问: 使用 socat-fix.sh
```

---

### 问题 3: agent-server 容器未启动

**症状**:
```
✗ 未发现 agent-server 容器
```

**解决方案**:
1. 通过 Web UI 创建新会话
2. 或重启 OpenHands Pod:
   ```bash
   kubectl delete pod -n openhands-dev <openhands-pod>
   ```

---

## 📝 脚本对比

| 脚本 | 类型 | 推荐度 | 用途 | 永久修复 |
|------|------|--------|------|----------|
| `debug-dind-deployment.sh` | 诊断 | ⭐⭐ | 基本检查 | N/A |
| `diagnose-agent-network.sh` | 诊断 | ⭐⭐⭐⭐ | 详细网络诊断 | N/A |
| `test-agent-connection.sh` | 诊断 | ⭐⭐ | 连接测试 | N/A |
| `test-dind-connectivity.sh` | 诊断 | ⭐⭐⭐⭐⭐ | 全面连接测试 + 建议 | N/A |
| `socat-fix.sh` | 修复 | ⭐⭐ | 临时端口转发 | ❌ |
| `DIND_TROUBLESHOOTING.md` | 文档 | ⭐⭐⭐⭐⭐ | 完整指南 | N/A |

---

## 🔗 相关文档

- [DinD 部署指南](./README_DIND_DEPLOYMENT.md)
- [K8S Runtime 指南](./K8S_RUNTIME_GUIDE.md)
- [Helm 命令速查](../OPENHANDS_HELM_COMMANDS.md)

---

## 💡 最佳实践

1. **始终先运行诊断脚本**，了解问题根源
2. **优先使用 `test-dind-connectivity.sh`**，它会推荐最佳方案
3. **优先选择永久修复**（修改配置），而非临时修复（socat）
4. **修改配置后重启 Pod**，确保配置生效
5. **创建新会话测试**，验证修复是否有效

---

## 🆘 获取帮助

如果问题持续:

1. 收集诊断信息:
   ```bash
   ./diagnose-agent-network.sh > /tmp/diagnose.txt 2>&1
   ./test-dind-connectivity.sh > /tmp/test-connectivity.txt 2>&1
   ```

2. 收集日志:
   ```bash
   kubectl logs -n openhands-dev <openhands-pod> > /tmp/openhands.log
   kubectl exec -n openhands-dev <dind-pod> -- docker logs <agent-container> > /tmp/agent-server.log
   ```

3. 查看完整故障排查指南:
   ```bash
   cat DIND_TROUBLESHOOTING.md
   ```

---

**最后更新**: 2026-02-13
**维护者**: OpenHands Team
