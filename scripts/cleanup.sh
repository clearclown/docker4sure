#!/bin/bash
# docker4sure: Automated container cleanup
# Removes unused images and build cache older than 7 days
# Safe: running containers' images are never removed
set -euo pipefail

LOG_FILE="$HOME/.containers/data/cleanup.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "Starting cleanup..."

# Podman: prune unused images older than 7 days
if command -v podman &>/dev/null; then
    log "Podman: pruning unused images..."
    podman image prune -af --filter "until=168h" 2>&1 | tail -1 | while read -r line; do log "  $line"; done
    log "Podman: pruning build cache..."
    podman builder prune -af --filter "until=168h" 2>&1 | tail -1 | while read -r line; do log "  $line"; done
fi

# Docker (real): prune if available
if [[ -x /usr/bin/docker ]]; then
    log "Docker: pruning unused images..."
    /usr/bin/docker image prune -af --filter "until=168h" 2>&1 | tail -1 | while read -r line; do log "  $line"; done
    log "Docker: pruning build cache..."
    /usr/bin/docker builder prune -af --filter "until=168h" 2>&1 | tail -1 | while read -r line; do log "  $line"; done
fi

log "Cleanup completed."
