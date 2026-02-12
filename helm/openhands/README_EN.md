# OpenHands Helm Chart

[OpenHands](https://github.com/OpenHands/OpenHands) is an AI-powered software engineer that can be deployed to Kubernetes clusters using Helm.

## Features

- Complete OpenHands application deployment
- Customizable image tags for all components
- Persistent volume support
- ConfigMap and Secret management
- Horizontal Pod Autoscaler (HPA)
- Ingress support
- Resource limits and requests configuration

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- PV provisioner support in the underlying infrastructure
- Docker socket access (if using Docker runtime)

## Installation

### Install from local chart

```bash
# Clone the repository
git clone https://github.com/OpenHands/OpenHands.git
cd OpenHands/helm/openhands

# Install the chart
helm install openhands ./openhands
```

### Quick install with default configuration

```bash
helm install openhands ./openhands \
  --set openhands.llm.apiKey=your-api-key \
  --set openhands.llm.model=gpt-4o
```

## Configuration

### Custom Image Tags (Key Feature)

You can specify tags for all images used by OpenHands:

```bash
helm install openhands ./openhands \
  --set image.repository=docker.openhands.dev/openhands/openhands \
  --set image.tag=v0.0.1 \
  --set image.runtime.repository=ghcr.io/openhands/runtime \
  --set image.runtime.tag=v0.0.1-runtime \
  --set image.agentServer.repository=ghcr.io/openhands/agent-server \
  --set image.agentServer.tag=v0.0.1-agent \
  --set image.uv.repository=ghcr.io/astral-sh/uv \
  --set image.uv.tag=latest
```

Or configure in values.yaml:

```yaml
image:
  repository: docker.openhands.dev/openhands/openhands
  tag: v0.0.1
  runtime:
    repository: ghcr.io/openhands/runtime
    tag: v0.0.1-runtime
  agentServer:
    repository: ghcr.io/openhands/agent-server
    tag: v0.0.1-agent
  uv:
    repository: ghcr.io/astral-sh/uv
    tag: latest
```

### LLM Configuration

OpenHands requires an LLM API key to function:

```bash
helm install openhands ./openhands \
  --set openhands.llm.apiKey=sk-... \
  --set openhands.llm.model=gpt-4o \
  --set openhands.llm.baseURL=https://api.openai.com/v1
```

### Persistent Storage

By default, 10Gi of persistent storage is enabled. Customize storage:

```bash
helm install openhands ./openhands \
  --set persistence.size=20Gi \
  --set persistence.storageClass=fast-ssd
```

Use existing PVC:

```bash
helm install openhands ./openhands \
  --set persistence.enabled=true \
  --set persistence.existingClaim=openhands-data
```

### Ingress Configuration

Enable Ingress for external access:

```bash
helm install openhands ./openhands \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.hosts[0].host=openhands.example.com \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix
```

### Resource Configuration

Adjust CPU and memory resources:

```bash
helm install openhands ./openhands \
  --set resources.requests.cpu=2 \
  --set resources.requests.memory=4Gi \
  --set resources.limits.cpu=8 \
  --set resources.limits.memory=16Gi
```

## Upgrade

```bash
helm upgrade openhands ./openhands
```

## Uninstall

```bash
helm uninstall openhands
```

## Configuration Parameters

### Image Parameters (Important)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Main application image repository | `docker.openhands.dev/openhands/openhands` |
| `image.tag` | Main application image tag | `latest` |
| `image.runtime.repository` | Runtime image repository | `ghcr.io/openhands/runtime` |
| `image.runtime.tag` | Runtime image tag | `latest` |
| `image.agentServer.repository` | Agent server image repository | `ghcr.io/openhands/agent-server` |
| `image.agentServer.tag` | Agent server image tag | `latest` |
| `image.uv.repository` | UV image repository | `ghcr.io/astral-sh/uv` |
| `image.uv.tag` | UV image tag | `latest` |

### OpenHands Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `openhands.llm.model` | LLM model | `gpt-4o` |
| `openhands.llm.apiKey` | LLM API key | `""` |
| `openhands.llm.baseURL` | LLM API base URL | `""` |
| `openhands.workspace.base` | Workspace base path | `/opt/workspace_base` |
| `openhands.sandbox.runtime` | Sandbox runtime type | `docker` |
| `openhands.sandbox.maxIterations` | Maximum iterations | `500` |
| `openhands.security.enableAnalyzer` | Enable security analyzer | `true` |
| `openhands.browser.enabled` | Enable browser | `true` |
| `openhands.jwtSecret` | JWT secret | `""` |

### Kubernetes Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `persistence.enabled` | Enable persistence | `true` |
| `persistence.size` | Storage size | `10Gi` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `3000` |
| `ingress.enabled` | Enable Ingress | `false` |
| `resources.requests.cpu` | CPU request | `1` |
| `resources.requests.memory` | Memory request | `2Gi` |
| `resources.limits.cpu` | CPU limit | `4` |
| `resources.limits.memory` | Memory limit | `8Gi` |

For more configuration options, see the `values.yaml` file.

## License

Apache-2.0

## Support

- GitHub Issues: https://github.com/OpenHands/OpenHands/issues
- Documentation: https://docs.openhands.dev
