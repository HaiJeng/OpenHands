#!/bin/bash
set -eo pipefail

echo "Starting OpenHands..."

# ⭐ Patch host-gateway issue for Kubernetes/DinD deployments
if [ -n "$SANDBOX_DISABLE_EXTRA_HOSTS" ]; then
  PYTHON_FILE="/app/.venv/lib/python3.13/site-packages/openhands/app_server/sandbox/docker_sandbox_service.py"
  
  if [ -f "$PYTHON_FILE" ]; then
    echo "Patching $PYTHON_FILE to disable host-gateway..."
    
    # Replace the default_factory lambda to check SANDBOX_DISABLE_EXTRA_HOSTS
    # Old: default_factory=lambda: {'host.docker.internal': 'host-gateway'},
    # New: default_factory=lambda: {'host.docker.internal': 'host-gateway'} if not os.getenv('SANDBOX_DISABLE_EXTRA_HOSTS') else {},
    
    if ! grep -q "SANDBOX_DISABLE_EXTRA_HOSTS" "$PYTHON_FILE"; then
      # Find and replace the default_factory line
      sed -i "s/default_factory=lambda: {'host.docker.internal': 'host-gateway'}/default_factory=lambda: {'host.docker.internal': 'host-gateway'} if not os.getenv('SANDBOX_DISABLE_EXTRA_HOSTS') else {}/" "$PYTHON_FILE"
      echo "Patch applied: host-gateway disabled when SANDBOX_DISABLE_EXTRA_HOSTS is set"
    else
      echo "Already patched, skipping..."
    fi
  else
    echo "WARNING: $PYTHON_FILE not found, skipping host-gateway patch"
  fi
fi

if [[ $NO_SETUP == "true" ]]; then
  echo "Skipping setup, running as $(whoami)"
  "$@"
  exit 0
fi


if [ -z "$SANDBOX_USER_ID" ]; then
  echo "SANDBOX_USER_ID is not set"
  exit 1
fi

if [ -z "$WORKSPACE_MOUNT_PATH" ]; then
  # This is set to /opt/workspace in the Dockerfile. But if the user isn't mounting, we want to unset it so that OpenHands doesn't mount at all
  unset WORKSPACE_BASE
fi

if [[ "$INSTALL_THIRD_PARTY_RUNTIMES" == "true" ]]; then
  echo "Downloading and installing third_party_runtimes..."
  echo "Warning: Third-party runtimes are provided as-is, not actively supported and may be removed in future releases."

  if pip install 'openhands-ai[third_party_runtimes]' -qqq 2> >(tee /dev/stderr); then
    echo "third_party_runtimes installed successfully."
  else
    echo "Failed to install third_party_runtimes." >&2
    exit 1
  fi
fi

if [[ "$SANDBOX_USER_ID" -eq 0 ]]; then
  echo "Running OpenHands as root"
  export RUN_AS_OPENHANDS=false
  "$@"
else
  echo "Setting up enduser with id $SANDBOX_USER_ID"
  if id "enduser" &>/dev/null; then
    echo "User enduser already exists. Skipping creation."
  else
    if ! useradd -l -m -u $SANDBOX_USER_ID -s /bin/bash enduser; then
      echo "Failed to create user enduser with id $SANDBOX_USER_ID. Moving openhands user."
      incremented_id=$(($SANDBOX_USER_ID + 1))
      usermod -u $incremented_id openhands
      if ! useradd -l -m -u $SANDBOX_USER_ID -s /bin/bash enduser; then
        echo "Failed to create user enduser with id $SANDBOX_USER_ID for a second time. Exiting."
        exit 1
      fi
    fi
  fi
  usermod -aG openhands enduser
  # get the user group of /var/run/docker.sock and set openhands to that group
  DOCKER_SOCKET_GID=$(stat -c '%g' /var/run/docker.sock)
  echo "Docker socket group id: $DOCKER_SOCKET_GID"
  if getent group $DOCKER_SOCKET_GID; then
    echo "Group with id $DOCKER_SOCKET_GID already exists"
  else
    echo "Creating group with id $DOCKER_SOCKET_GID"
    groupadd -g $DOCKER_SOCKET_GID docker
  fi

  mkdir -p /home/enduser/.cache/huggingface/hub/

  usermod -aG $DOCKER_SOCKET_GID enduser
  echo "Running as enduser"
  su enduser /bin/bash -c "${*@Q}" # This magically runs any arguments passed to the script as a command
fi
