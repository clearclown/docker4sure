#!/bin/bash
# docker4sure: Deploy Portainer Agent to a remote host
# Usage: deploy-agent.sh <host-ip> [ssh-user]
set -euo pipefail

HOST="${1:-}"
USER="${2:-$(whoami)}"
AGENT_IMAGE="portainer/agent:lts"

if [[ -z "$HOST" ]]; then
    echo "Usage: deploy-agent.sh <host-ip> [ssh-user]"
    echo ""
    echo "Examples:"
    echo "  deploy-agent.sh 100.83.54.6              # macOS (Tailscale)"
    echo "  deploy-agent.sh 100.82.83.122 kali        # Kali Linux (Tailscale)"
    exit 1
fi

echo "Deploying Portainer Agent to ${USER}@${HOST}..."

# Detect remote container runtime
REMOTE_CMD=$(ssh "${USER}@${HOST}" 'command -v podman || command -v docker' 2>/dev/null)
if [[ -z "$REMOTE_CMD" ]]; then
    echo "Error: No container runtime found on ${HOST}" >&2
    exit 1
fi

RUNTIME=$(basename "$REMOTE_CMD")
echo "Detected runtime: $RUNTIME"

# Determine socket path
if [[ "$RUNTIME" == "podman" ]]; then
    SOCKET_PATH="/run/user/\$(id -u)/podman/podman.sock"
    # Ensure podman socket is enabled
    ssh "${USER}@${HOST}" "systemctl --user enable --now podman.socket" 2>/dev/null || true
else
    SOCKET_PATH="/var/run/docker.sock"
fi

# Deploy agent
ssh "${USER}@${HOST}" bash <<REMOTE_SCRIPT
set -e
$RUNTIME stop portainer_agent 2>/dev/null || true
$RUNTIME rm portainer_agent 2>/dev/null || true
$RUNTIME run -d \
    --name portainer_agent \
    --restart=always \
    -p 9001:9001 \
    -v ${SOCKET_PATH}:/var/run/docker.sock \
    ${AGENT_IMAGE}
echo "Portainer Agent deployed successfully on \$(hostname)"
REMOTE_SCRIPT

echo ""
echo "Done! Add this environment in Portainer CE:"
echo "  URL: ${HOST}:9001"
echo "  Type: Agent"
