# OpenHands 本地开发构建指南

## 概述

本指南介绍如何使用基础镜像加速本地开发迭代，避免每次代码修改都重新构建整个镜像。

## 架构说明

### 传统构建方式
```
代码修改 → 完整构建 (15-30分钟) → 测试
```

### 基础镜像方式（推荐）
```
首次: 构建基础镜像 (15-30分钟)
后续: 代码修改 → 快速构建 (1-3分钟) → 测试
```

## 快速开始

### 1. 构建基础镜像（首次）

```bash
# 进入项目目录
cd /workspace/project/OpenHands

# 构建基础镜像（包含所有依赖）
./build-base.sh

# 等待构建完成（约 15-30 分钟）
```

**输出示例：**
```
========================================
OpenHands Base Image Builder
========================================

开始构建 base 基础镜像...
Dockerfile: containers/app/Dockerfile
镜像名: openhands-base
标签: latest

[构建日志...]

✓ 基础镜像构建成功！
镜像: openhands-base:latest

REPOSITORY          TAG       SIZE      CREATED
openhands-base      latest    1.5GB     2024-02-12 14:30:00
```

### 2. 快速开发构建

```bash
# 修改代码后，快速构建
./build-dev.sh

# 或使用优化的 Dockerfile
./build-dev.sh --optimized
```

**输出示例：**
```
========================================
OpenHands 快速开发构建
========================================

检查基础镜像...
✓ 找到基础镜像: openhands-base:latest

开始构建应用镜像...
最近修改的文件:
M openhands/server/listen.py
M containers/app/entrypoint.sh

构建命令: docker build -f containers/app/Dockerfile --cache-from openhands-base:latest -t openhands:dev .

[快速构建日志...]

✓ 应用镜像构建成功！
REPOSITORY          TAG       SIZE      CREATED
openhands           dev       1.6GB     2024-02-12 14:35:00

是否要运行容器测试？(y/N) y

启动容器测试...
容器已启动！
容器名: openhands-dev
端口: 3000

访问应用:
http://localhost:3000
```

## 脚本详解

### build-base.sh - 构建基础镜像

**用途：** 构建包含所有依赖的基础镜像

**何时使用：**
- 首次设置开发环境
- `pyproject.toml` 或 `poetry.lock` 更新
- `package.json` 或 `package-lock.json` 更新
- 基础系统包更新

**选项：**
```bash
./build-base.sh              # 标准构建
./build-base.sh --force      # 强制重新构建（无缓存）
./build-base.sh --push       # 构建并推送到 registry
```

### build-dev.sh - 快速开发构建

**用途：** 基于基础镜像快速构建应用代码

**何时使用：**
- 修改 Python 代码
- 修改前端代码
- 修改 entrypoint.sh
- 任何应用层代码变更

**选项：**
```bash
./build-dev.sh               # 标准快速构建
./build-dev.sh --no-cache    # 不使用缓存
./build-dev.sh --tag test    # 使用自定义标签
```

## 工作流程

### 标准开发流程

```bash
# 1. 首次设置（一次性）
./build-base.sh

# 2. 开发循环
# 修改代码 → 构建 → 测试
vim openhands/server/listen.py
./build-dev.sh
docker logs -f openhands-dev

# 3. 重复步骤 2 直到满意

# 4. 清理（可选）
docker stop openhands-dev
docker rm openhands-dev
```

### 多人协作流程

```bash
# 1. 拉取最新代码
git pull origin main

# 2. 检查是否需要重新构建基础镜像
git diff pyproject.toml poetry.lock package.json
# 如果有变化，重新构建基础镜像
./build-base.sh --force

# 3. 快速构建应用
./build-dev.sh

# 4. 测试
docker logs -f openhands-dev
```

## 镜像层级结构

### 基础镜像 (openhands-base:latest)
```
├── Python 3.13.7
├── Poetry 依赖
│   ├── FastAPI
│   ├── Pydantic
│   ├── LangChain
│   └── ... (所有 Python 包)
├── Node.js 25.2
├── npm 依赖
│   ├── React
│   ├── TypeScript
│   └── ... (所有前端包)
├── 系统依赖
│   ├── git, curl, make
│   └── build-essential
└── OpenHands 用户设置
    ├── UID: 42420
    └── 工作目录
```

### 应用镜像 (openhands:dev)
```
├── FROM openhands-base:latest
├── 应用代码
│   ├── openhands/
│   ├── frontend/
│   └── skills/
├── 配置文件
│   ├── entrypoint.sh
│   └── pyproject.toml
└── 元数据
    ├── ENV 变量
    └── ENTRYPOINT
```

## 优化技巧

### 1. 使用 .dockerignore

创建 `.dockerignore` 文件以排除不必要的文件：

```
.git
.gitignore
.env
.venv
__pycache__
*.pyc
*.pyo
*.pyd
.Python
node_modules
npm-debug.log
.DS_Store
.idea
.vscode
*.md
!README.md
```

### 2. 利用 BuildKit

```bash
# 启用 BuildKit（已在脚本中设置）
export DOCKER_BUILDKIT=1

# 或在 ~/.bashrc 中添加
echo 'export DOCKER_BUILDKIT=1' >> ~/.bashrc
```

### 3. 多阶段构建缓存

使用优化的 Dockerfile：

```bash
# 使用优化版本
./build-dev.sh --optimized
```

### 4. 并行构建

如果有多个服务：

```bash
# 使用 docker-compose
docker-compose build --parallel

# 或使用 BuildKit 的并行功能
DOCKER_BUILDKIT=1 docker build .
```

## 常见问题

### Q1: 基础镜像多久需要重建一次？

**A**: 通常在以下情况需要重建：
- `pyproject.toml` 添加/删除依赖
- `package.json` 添加/删除依赖
- 升级 Python/Node.js 版本
- 约 1-2 周一次（可选）

### Q2: 快速构建需要多长时间？

**A**: 取决于修改的文件：
- 仅修改 Python 代码：30秒 - 1分钟
- 修改前端代码：1-2分钟
- 修改 entrypoint.sh：30秒
- 完整重建（无缓存）：3-5分钟

### Q3: 如何判断是否需要重建基础镜像？

**A**: 运行以下命令检查：

```bash
# 检查依赖文件是否变化
git diff HEAD~10 pyproject.toml poetry.lock package.json

# 如果有变化，重建基础镜像
if git diff HEAD~10 pyproject.toml poetry.lock package.json | grep -q .; then
    echo "需要重建基础镜像"
    ./build-base.sh
fi
```

### Q4: 可以使用远程基础镜像吗？

**A**: 可以！修改 `build-dev.sh` 中的 `BASE_IMAGE`：

```bash
# 使用 GHCR 上的镜像
BASE_IMAGE="ghcr.io/openhands/openhands-base:latest"

# 或使用私有 registry
BASE_IMAGE="harbor.example.com/openhands/base:latest"
```

### Q5: 如何清理旧镜像？

**bash**:
```bash
# 清理悬空镜像
docker image prune

# 清理所有未使用的镜像
docker image prune -a

# 清理特定名称的镜像
docker images | grep openhands | awk '{print $3}' | xargs docker rmi -f
```

## 高级用法

### 1. 多环境构建

```bash
# 开发环境
./build-dev.sh --tag dev

# 测试环境
./build-dev.sh --tag test

# 生产环境
./build-base.sh --push
./build-dev.sh --tag prod
```

### 2. CI/CD 集成

```yaml
# .github/workflows/build.yml
name: Build
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build base image
        run: ./build-base.sh
        
      - name: Build app image
        run: ./build-dev.sh --tag ${{ github.sha }}
        
      - name: Push to registry
        run: docker push openhands:${{ github.sha }}
```

### 3. 本地 Registry

```bash
# 启动本地 registry
docker run -d -p 5000:5000 --name registry registry:2

# 推送到本地 registry
docker tag openhands:dev localhost:5000/openhands:dev
docker push localhost:5000/openhands:dev
```

### 4. 镜像层缓存

```bash
# 使用镜像层缓存加速构建
docker build \
  --cache-from openhands-base:latest \
  --cache-from openhands:dev \
  -t openhands:dev \
  .
```

## 性能对比

| 操作 | 传统方式 | 基础镜像方式 | 提升 |
|------|----------|--------------|------|
| 首次构建 | 15-30分钟 | 15-30分钟 | - |
| 代码修改后重建 | 15-30分钟 | 30秒-3分钟 | **10-60倍** |
| 依赖更新后重建 | 15-30分钟 | 15-30分钟 | - |
| CI/CD 构建 | 15-30分钟 | 3-5分钟 | **3-10倍** |

## 最佳实践

### 1. 定期更新基础镜像
```bash
# 每周一次
./build-base.sh --force
```

### 2. 使用版本标签
```bash
# 不要只用 latest
./build-base.sh --tag v1.0.0
./build-dev.sh --tag v1.0.1
```

### 3. 监控镜像大小
```bash
# 检查镜像大小
docker images openhands

# 如果太大，考虑优化 Dockerfile
```

### 4. 测试基础镜像
```bash
# 构建后立即测试
./build-base.sh && ./build-dev.sh
```

### 5. 文档化构建过程
```bash
# 在 README 中记录构建步骤
echo "## 构建\n\n1. ./build-base.sh\n2. ./build-dev.sh" >> README.md
```

## 故障排查

### 问题1: 基础镜像构建失败

```bash
# 检查 Docker 日志
journalctl -u docker

# 检查磁盘空间
df -h

# 清理空间
docker system prune -a
```

### 问题2: 快速构建未使用缓存

```bash
# 确保基础镜像存在
docker images | grep openhands-base

# 检查 BUILDKIT 设置
echo $DOCKER_BUILDKIT

# 强制使用缓存
docker build --cache-from openhands-base:latest .
```

### 问题3: 权限问题

```bash
# 修复脚本权限
chmod +x build-*.sh

# 检查 Docker 权限
sudo usermod -aG docker $USER
```

## 总结

使用基础镜像方式可以将开发迭代时间从 **15-30分钟** 缩短到 **30秒-3分钟**，提升 **10-60倍** 的效率！

**推荐工作流程：**
1. 首次：`./build-base.sh`
2. 日常开发：修改代码 → `./build-dev.sh` → 测试
3. 依赖更新：`./build-base.sh`
4. 定期清理：`docker system prune`

现在您可以享受快速的开发迭代了！🚀
