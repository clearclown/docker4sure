#!/bin/bash
# docker4sure uninstaller
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="$HOME/.containers"

log()  { echo -e "${GREEN}[docker4sure]${NC} $*"; }
warn() { echo -e "${YELLOW}[docker4sure]${NC} $*"; }

echo -e "${YELLOW}docker4sure uninstaller${NC}"
echo ""
echo "This will remove:"
echo "  - $INSTALL_DIR/bin/ (wrapper scripts)"
echo "  - $INSTALL_DIR/compose/ (compose files)"
echo "  - $INSTALL_DIR/scripts/ (utility scripts)"
echo "  - systemd cleanup timer"
echo "  - PATH entry from shell config"
echo ""
echo -e "${GREEN}Data directories ($INSTALL_DIR/data/) will NOT be removed.${NC}"
echo ""
read -rp "Continue? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Stop services
if command -v podman-compose &>/dev/null && [[ -d "$INSTALL_DIR/compose" ]]; then
    log "Stopping services..."
    cd "$INSTALL_DIR/compose"
    local_args=()
    for f in *.yml; do
        [[ -f "$f" ]] && local_args+=("-f" "$f")
    done
    podman-compose "${local_args[@]}" down 2>/dev/null || true
fi

# Disable systemd timer
if [[ "$(uname -s)" == "Linux" ]]; then
    log "Disabling systemd timer..."
    systemctl --user disable --now container-cleanup.timer 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/container-cleanup.timer"
    rm -f "$HOME/.config/systemd/user/container-cleanup.service"
    systemctl --user daemon-reload 2>/dev/null || true
fi

# Remove scripts and compose
log "Removing installed files..."
rm -rf "$INSTALL_DIR/bin"
rm -rf "$INSTALL_DIR/compose"
rm -rf "$INSTALL_DIR/scripts"

# Remove PATH from shell config
for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
    if [[ -f "$rc" ]] && grep -qF '.containers/bin' "$rc"; then
        log "Removing PATH from $rc..."
        sed -i '/# docker4sure: docker->podman redirect/d' "$rc"
        sed -i '/\.containers\/bin/d' "$rc"
    fi
done

echo ""
log "Uninstall complete."
echo ""
echo -e "  ${YELLOW}Data preserved at: $INSTALL_DIR/data/${NC}"
echo -e "  To remove data too: rm -rf $INSTALL_DIR"
echo ""
echo -e "  Restart your shell to restore original docker command."
