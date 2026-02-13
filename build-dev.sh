#!/bin/bash
# OpenHands 快速开发构建脚本
# 基于基础镜像快速构建，大幅加快迭代速度

set -e

# 配置
IMAGE_NAME="harbor.inspur.local/open-hands/openhands"
IMAGE_TAG="dev"
BASE_IMAGE="openhands-base:latest"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}OpenHands 快速开发构建${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查基础镜像是否存在
check_base_image() {
    echo -e "${YELLOW}检查基础镜像...${NC}"

    if docker images "${BASE_IMAGE}" --format "{{.Repository}}:{{.Tag}}" | grep -q "${BASE_IMAGE}"; then
        echo -e "${GREEN}✓ 找到基础镜像: ${BASE_IMAGE}${NC}"
        docker images "${BASE_IMAGE}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ 未找到基础镜像: ${BASE_IMAGE}${NC}"
        echo ""
        echo -e "${YELLOW}请先运行: ./build-base.sh${NC}"
        echo ""
        return 1
    fi
}

# 构建应用镜像
build_app_image() {
    echo -e "${GREEN}开始构建应用镜像...${NC}"
    echo ""

    # 检查修改的文件
    echo -e "${YELLOW}最近修改的文件:${NC}"
    git status --short 2>/dev/null || echo "(Git 信息不可用)"
    echo ""

    # 构建命令
    BUILD_CMD=(
        "docker" "build"
        "-f" "containers/app/Dockerfile"
        "--cache-from" "${BASE_IMAGE}"
        "-t" "${IMAGE_NAME}:${IMAGE_TAG}"
        "."
    )

    # 可选：使用 BuildKit 获取更好的输出
    export DOCKER_BUILDKIT=1

    echo -e "${YELLOW}构建命令: ${BUILD_CMD[*]}${NC}"
    echo ""

    if "${BUILD_CMD[@]}"; then
        echo ""
        echo -e "${GREEN}✓ 应用镜像构建成功！${NC}"
        docker images "${IMAGE_NAME}:${IMAGE_TAG}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    else
        echo ""
        echo -e "${RED}✗ 应用镜像构建失败${NC}"
        exit 1
    fi
}

# 测试镜像
test_image() {
    echo ""
    echo -e "${YELLOW}是否要运行容器测试？(y/N)${NC}"
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${GREEN}启动容器测试...${NC}"
        echo ""

        # 检查端口 3000 是否被占用
        if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1; then
            echo -e "${YELLOW}警告: 端口 3000 已被占用${NC}"
            echo -e "${YELLOW}是否要清理旧容器？(y/N)${NC}"
            read -r cleanup
            if [[ "$cleanup" =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}停止旧容器...${NC}"
                docker stop openhands-dev 2>/dev/null || true
                docker rm openhands-dev 2>/dev/null || true
            else
                echo -e "${RED}使用不同端口启动: 3001${NC}"
                PORT=3001
            fi
        fi

        PORT=${PORT:-3000}

        # 启动容器
        docker run -d \
            --name "openhands-dev" \
            -p "${PORT}:3000" \
            -e OPENHANDS_LLM_API_KEY=test-key \
            -e OPENHANDS_LLM_MODEL=gpt-4o \
            "${IMAGE_NAME}:${IMAGE_TAG}"

        echo ""
        echo -e "${GREEN}容器已启动！${NC}"
        echo -e "${GREEN}容器名: openhands-dev${NC}"
        echo -e "${GREEN}端口: ${PORT}${NC}"
        echo ""
        echo -e "${YELLOW}查看日志:${NC}"
        echo "docker logs -f openhands-dev"
        echo ""
        echo -e "${YELLOW}访问应用:${NC}"
        echo "http://localhost:${PORT}"
    fi
}

# 显示构建统计
show_stats() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}构建统计${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    # 显示镜像大小
    echo -e "${YELLOW}镜像大小对比:${NC}"
    echo ""
    echo "基础镜像:"
    docker images "${BASE_IMAGE}" --format "  {{.Repository}}:{{.Tag}} - {{.Size}}"
    echo ""
    echo "应用镜像:"
    docker images "${IMAGE_NAME}:${IMAGE_TAG}" --format "  {{.Repository}}:{{.Tag}} - {{.Size}}"
    echo ""

    # 显示构建历史（如果有）
    echo -e "${YELLOW}构建历史:${NC}"
    docker images "${IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | head -5
    echo ""
}

# 主流程
main() {
    # 检查基础镜像
    if ! check_base_image; then
        exit 1
    fi

    # 构建应用镜像
    build_app_image

    # 测试镜像（可选）
    test_image

    # 显示统计
    show_stats

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}快速构建完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}常用命令:${NC}"
    echo ""
    echo -e "${GREEN}# 查看镜像${NC}"
    echo "docker images openhands"
    echo ""
    echo -e "${GREEN}# 运行容器${NC}"
    echo "docker run -d -p 3000:3000 --name openhands ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
    echo -e "${GREEN}# 查看日志${NC}"
    echo "docker logs -f openhands"
    echo ""
    echo -e "${GREEN}# 进入容器${NC}"
    echo "docker exec -it openhands /bin/bash"
    echo ""
    echo -e "${GREEN}# 停止并删除容器${NC}"
    echo "docker stop openhands && docker rm openhands"
    echo ""
    echo -e "${GREEN}# 重新构建基础镜像（当依赖变化时）${NC}"
    echo "./build-base.sh"
    echo ""
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "快速开发构建脚本，基于基础镜像构建应用镜像"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  --no-cache     不使用缓存重新构建"
    echo "  --tag TAG      指定镜像标签 (默认: dev)"
    echo ""
    echo "示例:"
    echo "  $0                  # 快速构建"
    echo "  $0 --tag test       # 使用自定义标签"
    echo "  $0 --no-cache       # 清除缓存重新构建"
    echo ""
}

# 解析参数
NO_CACHE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}未知参数: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 执行主流程
main
