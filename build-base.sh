#!/bin/bash
# OpenHands Base Image Build Script
# 用于构建基础镜像，后续快速迭代的构建脚本

set -e

# 配置
BASE_IMAGE_NAME="openhands-base"
BASE_IMAGE_TAG="latest"
REGISTRY="ghcr.io/openhands"
FULL_IMAGE_NAME="${REGISTRY}/${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}OpenHands Base Image Builder${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 检查 Docker 是否运行
if ! docker info &> /dev/null; then
    echo -e "${RED}错误: Docker 未运行${NC}"
    echo "请先启动 Docker daemon"
    exit 1
fi

# 解析参数
PUSH_FLAG=""
FORCE_FLAG=""
TARGET="base"

while [[ $# -gt 0 ]]; do
    case $1 in
        --push)
            PUSH_FLAG="--push"
            shift
            ;;
        --force)
            FORCE_FLAG="--force"
            shift
            ;;
        --runtime)
            TARGET="runtime"
            shift
            ;;
        *)
            echo "用法: $0 [--push] [--force] [--runtime]"
            echo ""
            echo "选项:"
            echo "  --push    构建后推送到 registry"
            echo "  --force   强制重新构建（忽略缓存）"
            echo "  --runtime  构建 runtime 基础镜像而非 app 基础镜像"
            exit 1
            ;;
    esac
done

echo -e "${YELLOW}目标: ${TARGET}${NC}"
echo ""

# 构建 Base 镜像
build_base() {
    echo -e "${GREEN}开始构建 ${TARGET} 基础镜像...${NC}"
    
    if [ "$TARGET" = "runtime" ]; then
        # 构建运行时基础镜像
        BASE_DOCKERFILE="third_party/containers/e2b-sandbox/Dockerfile"
        IMAGE_NAME="openhands-runtime-base"
    else
        # 构建应用基础镜像
        BASE_DOCKERFILE="containers/app/Dockerfile"
        IMAGE_NAME="${BASE_IMAGE_NAME}"
    fi
    
    # 构建参数
    BUILD_ARGS=(
        "--build-arg" "OPENHANDS_BUILD_VERSION=dev"
    )
    
    if [ -n "$FORCE_FLAG" ]; then
        BUILD_ARGS+=("--no-cache")
        echo -e "${YELLOW}强制重新构建（无缓存）${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Dockerfile: ${BASE_DOCKERFILE}${NC}"
    echo -e "${YELLOW}镜像名: ${IMAGE_NAME}${NC}"
    echo -e "${YELLOW}标签: ${BASE_IMAGE_TAG}${NC}"
    echo ""
    
    # 构建
    if docker build \
        -f "${BASE_DOCKERFILE}" \
        "${BUILD_ARGS[@]}" \
        -t "${IMAGE_NAME}:${BASE_IMAGE_TAG}" \
        .; then
        echo -e "${GREEN}✓ 基础镜像构建成功！${NC}"
        echo -e "${GREEN}镜像: ${IMAGE_NAME}:${BASE_IMAGE_TAG}${NC}"
        
        # 显示镜像信息
        echo ""
        docker images "${IMAGE_NAME}:${BASE_IMAGE_TAG}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    else
        echo -e "${RED}✗ 基础镜像构建失败${NC}"
        exit 1
    fi
}

# 推送镜像
push_image() {
    if [ -z "$PUSH_FLAG" ]; then
        echo ""
        echo -e "${YELLOW}跳过推送（使用 --push 参数来推送）${NC}"
        return
    fi
    
    echo ""
    echo -e "${GREEN}开始推送基础镜像...${NC}"
    
    if docker push "${IMAGE_NAME}:${BASE_IMAGE_TAG}"; then
        echo -e "${GREEN}✓ 基础镜像推送成功！${NC}"
        echo -e "${GREEN}Registry: ${REGISTRY}${NC}"
    else
        echo -e "${RED}✗ 基础镜像推送失败${NC}"
        echo "请检查是否已登录到 registry"
        exit 1
    fi
}

# 保存基础镜像信息
save_base_info() {
    echo ""
    echo -e "${GREEN}保存基础镜像信息...${NC}"
    
    # 保存当前基础镜像的 tag 和构建时间
    echo "${IMAGE_NAME}:${BASE_IMAGE_TAG}" > .base-image-info
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> .base-image-info
    
    echo -e "${GREEN}基础镜像信息已保存到 .base-image-info${NC}"
    cat .base-image-info
}

# 主流程
main() {
    echo -e "${YELLOW}构建基础镜像流程：${NC}"
    echo "1. 构建基础镜像"
    echo "2. 保存基础镜像信息"
    echo "3. (可选) 推送到 registry"
    echo ""
    
    # 构建
    build_base
    
    # 保存信息
    save_base_info
    
    # 推送
    push_image
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}基础镜像构建完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}后续快速构建命令：${NC}"
    echo ""
    echo -e "${GREEN}# 使用基础镜像快速构建${NC}"
    echo "${GREEN}docker build -f containers/app/Dockerfile --cache-from=${FULL_IMAGE_NAME} -t openhands:dev .${NC}"
    echo ""
}

# 执行主流程
main
