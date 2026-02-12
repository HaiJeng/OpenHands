#!/bin/bash

# OpenHands Helm Chart Validation Script
# This script validates the Helm chart configuration before deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_info() {
    echo -e "ℹ $1"
}

# Check if required tools are installed
check_prerequisites() {
    echo "Checking prerequisites..."
    
    # Check kubectl
    if command -v kubectl &> /dev/null; then
        KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | grep -o 'GitVersion:"[^"]*"' | cut -d'"' -f2)
        print_success "kubectl is installed ($KUBECTL_VERSION)"
    else
        print_error "kubectl is not installed"
        echo "  Install: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    # Check helm
    if command -v helm &> /dev/null; then
        HELM_VERSION=$(helm version --short 2>/dev/null || helm version 2>/dev/null | grep -o 'Version:"[^"]*"' | cut -d'"' -f2)
        print_success "helm is installed ($HELM_VERSION)"
    else
        print_error "helm is not installed"
        echo "  Install: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    
    echo ""
}

# Check Kubernetes cluster connection
check_cluster() {
    echo "Checking Kubernetes cluster..."
    
    if kubectl cluster-info &> /dev/null; then
        CLUSTER_VERSION=$(kubectl version -o json 2>/dev/null | grep -o '"gitVersion":"[^"]*"' | head -1 | cut -d'"' -f4)
        print_success "Connected to Kubernetes cluster ($CLUSTER_VERSION)"
        
        # Check current context
        CURRENT_CONTEXT=$(kubectl config current-context)
        print_info "Current context: $CURRENT_CONTEXT"
    else
        print_error "Cannot connect to Kubernetes cluster"
        echo "  Make sure you have access to a cluster and kubeconfig is configured"
        exit 1
    fi
    
    echo ""
}

# Validate Helm chart syntax
validate_chart() {
    echo "Validating Helm chart syntax..."
    
    if helm lint . &> /dev/null; then
        print_success "Helm chart syntax is valid"
    else
        print_error "Helm chart has syntax errors"
        helm lint .
        exit 1
    fi
    
    echo ""
}

# Validate values file
validate_values() {
    echo "Validating values file..."
    
    if [ -f "values.yaml" ]; then
        print_success "values.yaml found"
        
        # Check for common issues
        if grep -q "apiKey: \"\"" values.yaml; then
            print_warning "LLM API key is empty in values.yaml"
            echo "  You'll need to set it during installation:"
            echo "    helm install openhands . --set openhands.llm.apiKey=your-key"
        fi
        
        if grep -q "jwtSecret: \"\"" values.yaml; then
            print_warning "JWT secret is empty in values.yaml"
            echo "  Consider generating a secure secret:"
            echo "    openssl rand -base64 32"
        fi
    else
        print_error "values.yaml not found"
        exit 1
    fi
    
    echo ""
}

# Check image tags configuration
check_images() {
    echo "Checking image configuration..."
    
    # Extract image settings from values.yaml
    MAIN_IMAGE=$(grep -A 3 "^image:" values.yaml | grep "repository:" | head -1 | awk '{print $2}')
    MAIN_TAG=$(grep -A 3 "^image:" values.yaml | grep "tag:" | head -1 | awk '{print $2}')
    
    print_info "Main image: $MAIN_IMAGE:$MAIN_TAG"
    
    # Check runtime image
    RUNTIME_IMAGE=$(grep -A 3 "runtime:" values.yaml | grep "repository:" | head -1 | awk '{print $2}')
    RUNTIME_TAG=$(grep -A 3 "runtime:" values.yaml | grep "tag:" | head -1 | awk '{print $2}')
    
    if [ -n "$RUNTIME_IMAGE" ]; then
        print_info "Runtime image: $RUNTIME_IMAGE:$RUNTIME_TAG"
    fi
    
    # Check agent server image
    AGENT_IMAGE=$(grep -A 3 "agentServer:" values.yaml | grep "repository:" | head -1 | awk '{print $2}')
    AGENT_TAG=$(grep -A 3 "agentServer:" values.yaml | grep "tag:" | head -1 | awk '{print $2}')
    
    if [ -n "$AGENT_IMAGE" ]; then
        print_info "Agent server image: $AGENT_IMAGE:$AGENT_TAG"
    fi
    
    # Check UV image
    UV_IMAGE=$(grep -A 3 "uv:" values.yaml | grep "repository:" | head -1 | awk '{print $2}')
    UV_TAG=$(grep -A 3 "uv:" values.yaml | grep "tag:" | head -1 | awk '{print $2}')
    
    if [ -n "$UV_IMAGE" ]; then
        print_info "UV image: $UV_IMAGE:$UV_TAG"
    fi
    
    # Check for latest tag
    if [[ "$MAIN_TAG" == "latest" || "$RUNTIME_TAG" == "latest" || "$AGENT_TAG" == "latest" ]]; then
        print_warning "Using 'latest' tag is not recommended for production"
        echo "  Consider pinning specific versions:"
        echo "    --set image.tag=v0.0.1"
        echo "    --set image.runtime.tag=v0.0.1-runtime"
        echo "    --set image.agentServer.tag=v0.0.1-agent"
    fi
    
    echo ""
}

# Check persistence configuration
check_persistence() {
    echo "Checking persistence configuration..."
    
    PERSISTENCE_ENABLED=$(grep "enabled:" values.yaml | grep -A 1 "persistence:" | tail -1 | awk '{print $2}')
    
    if [ "$PERSISTENCE_ENABLED" == "true" ]; then
        print_success "Persistence is enabled"
        
        PVC_SIZE=$(grep -A 5 "persistence:" values.yaml | grep "size:" | awk '{print $2}')
        print_info "PVC size: $PVC_SIZE"
        
        # Check if storage class is set
        STORAGE_CLASS=$(grep -A 5 "persistence:" values.yaml | grep "storageClass:" | awk '{print $2}')
        if [ -n "$STORAGE_CLASS" ]; then
            print_info "Storage class: $STORAGE_CLASS"
        else
            print_warning "No storage class specified, will use default"
        fi
    else
        print_warning "Persistence is disabled - data will be lost on pod restart"
    fi
    
    echo ""
}

# Check Docker socket configuration
check_docker_socket() {
    echo "Checking Docker socket configuration..."
    
    DOCKER_SOCKET_ENABLED=$(grep -A 2 "dockerSocket:" values.yaml | grep "enabled:" | awk '{print $2}')
    
    if [ "$DOCKER_SOCKET_ENABLED" == "true" ]; then
        print_warning "Docker socket mounting is enabled"
        echo "  This is required for Docker runtime but has security implications"
        echo "  Consider using Kubernetes runtime instead:"
        echo "    --set dockerSocket.enabled=false"
        echo "    --set openhands.sandbox.runtime=kubernetes"
    else
        print_success "Docker socket mounting is disabled"
    fi
    
    echo ""
}

# Generate deployment command
generate_deploy_command() {
    echo "Suggested deployment command:"
    echo ""
    
    CMD="helm install openhands ."
    
    # Check if API key is needed
    if grep -q 'apiKey: ""' values.yaml; then
        CMD="$CMD --set openhands.llm.apiKey=YOUR_API_KEY"
    fi
    
    # Check if using latest tags
    if grep -q "tag: latest" values.yaml; then
        CMD="$CMD --set image.tag=SPECIFIC_VERSION"
    fi
    
    echo "  $CMD"
    echo ""
    echo "Or with a custom values file:"
    echo "  helm install openhands . -f my-values.yaml"
    echo ""
}

# Main validation function
main() {
    echo "======================================"
    echo "OpenHands Helm Chart Validation"
    echo "======================================"
    echo ""
    
    check_prerequisites
    check_cluster
    validate_chart
    validate_values
    check_images
    check_persistence
    check_docker_socket
    generate_deploy_command
    
    echo "======================================"
    echo "Validation Complete!"
    echo "======================================"
}

# Run main function
main
