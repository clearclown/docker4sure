#!/bin/bash
# docker4sure installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/clearclown/docker4sure/main/install.sh | bash
#   ./install.sh [--server|--agent|--wrappers-only]
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="$HOME/.containers"
REPO_URL="https://raw.githubusercontent.com/clearclown/docker4sure/main"
MODE="${1:-interactive}"

log()  { echo -e "${GREEN}[docker4sure]${NC} $*"; }
warn() { echo -e "${YELLOW}[docker4sure]${NC} $*"; }
err()  { echo -e "${RED}[docker4sure]${NC} $*" >&2; }

detect_os() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "macos" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)       echo "unknown" ;;
    esac
}

detect_runtime() {
    if command -v podman &>/dev/null; then
        echo "podman"
    elif command -v docker &>/dev/null; then
        echo "docker"
    else
        echo "none"
    fi
}

download_file() {
    local src="$1" dst="$2"
    if command -v curl &>/dev/null; then
        curl -fsSL "$src" -o "$dst"
    elif command -v wget &>/dev/null; then
        wget -qO "$dst" "$src"
    else
        err "Neither curl nor wget found"
        exit 1
    fi
}

install_from_repo() {
    local src_dir="$1"
    if [[ -d "$src_dir" ]]; then
        log "Installing from local directory: $src_dir"
        INSTALL_SOURCE="local"
        LOCAL_DIR="$src_dir"
    else
        INSTALL_SOURCE="remote"
    fi
}

copy_file() {
    local rel_path="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [[ "${INSTALL_SOURCE:-remote}" == "local" ]]; then
        cp "$LOCAL_DIR/$rel_path" "$dst"
    else
        download_file "$REPO_URL/$rel_path" "$dst"
    fi
}

install_wrappers() {
    log "Installing wrapper scripts..."
    mkdir -p "$INSTALL_DIR/bin"

    for script in docker docker-compose docker4sure docker4sure-compose ctn; do
        copy_file "bin/$script" "$INSTALL_DIR/bin/$script"
        chmod +x "$INSTALL_DIR/bin/$script"
    done

    log "Wrapper scripts installed to $INSTALL_DIR/bin/"
}

install_compose() {
    log "Installing compose files..."
    mkdir -p "$INSTALL_DIR/compose"

    local files=("$@")
    for f in "${files[@]}"; do
        copy_file "compose/$f" "$INSTALL_DIR/compose/$f"
    done
}

install_scripts() {
    log "Installing scripts..."
    mkdir -p "$INSTALL_DIR/scripts"

    copy_file "scripts/cleanup.sh" "$INSTALL_DIR/scripts/cleanup.sh"
    chmod +x "$INSTALL_DIR/scripts/cleanup.sh"

    copy_file "scripts/port-monitor.sh" "$INSTALL_DIR/scripts/port-monitor.sh"
    chmod +x "$INSTALL_DIR/scripts/port-monitor.sh"
}

install_systemd() {
    local os="$1"
    if [[ "$os" != "linux" ]]; then
        warn "Skipping systemd timer (not Linux)"
        return
    fi

    log "Installing systemd user timer..."
    local systemd_dir="$HOME/.config/systemd/user"
    mkdir -p "$systemd_dir"

    copy_file "systemd/container-cleanup.timer" "$systemd_dir/container-cleanup.timer"
    copy_file "systemd/container-cleanup.service" "$systemd_dir/container-cleanup.service"

    systemctl --user daemon-reload
    systemctl --user enable --now container-cleanup.timer
    log "Cleanup timer enabled (weekly, Sun 03:00)"
}

install_agent_script() {
    log "Installing agent deploy script..."
    mkdir -p "$INSTALL_DIR/scripts"
    copy_file "agent/deploy-agent.sh" "$INSTALL_DIR/scripts/deploy-agent.sh"
    chmod +x "$INSTALL_DIR/scripts/deploy-agent.sh"
}

setup_path() {
    local shell_rc=""
    local path_line='export PATH="$HOME/.containers/bin:$PATH"'

    if [[ -f "$HOME/.zshrc" ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ -f "$HOME/.bashrc" ]]; then
        shell_rc="$HOME/.bashrc"
    elif [[ -f "$HOME/.bash_profile" ]]; then
        shell_rc="$HOME/.bash_profile"
    fi

    if [[ -z "$shell_rc" ]]; then
        warn "No shell config found. Add this to your shell profile:"
        warn "  $path_line"
        return
    fi

    if grep -qF '.containers/bin' "$shell_rc" 2>/dev/null; then
        log "PATH already configured in $shell_rc"
    else
        log "Adding PATH to $shell_rc..."
        # Insert before plugins block if zshrc, otherwise append
        if [[ "$shell_rc" == *".zshrc" ]] && grep -q '^plugins=' "$shell_rc"; then
            local line_num
            line_num=$(grep -n '^plugins=' "$shell_rc" | head -1 | cut -d: -f1)
            sed -i "${line_num}i\\
# docker4sure: docker->podman redirect\\
${path_line}\\
" "$shell_rc"
        else
            echo "" >> "$shell_rc"
            echo "# docker4sure: docker->podman redirect" >> "$shell_rc"
            echo "$path_line" >> "$shell_rc"
        fi
        log "PATH added to $shell_rc"
    fi
}

enable_podman_socket() {
    local os="$1"
    local runtime="$2"

    if [[ "$os" == "linux" && "$runtime" == "podman" ]]; then
        log "Enabling Podman socket..."
        systemctl --user enable --now podman.socket
        log "Podman socket active at /run/user/$(id -u)/podman/podman.sock"
    fi
}

create_data_dirs() {
    log "Creating data directories..."
    mkdir -p "$INSTALL_DIR/data"/{open-webui,portainer,port-monitor}
}

# === Main Install Logic ===

main() {
    echo -e "${CYAN}"
    echo "  docker4sure - Docker-to-Podman Transparent Redirect Toolkit"
    echo -e "${NC}"

    local os runtime
    os=$(detect_os)
    runtime=$(detect_runtime)

    log "OS: $os | Runtime: $runtime"

    # Check if running from local clone
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$script_dir/bin/docker" && -f "$script_dir/compose/base.yml" ]]; then
        install_from_repo "$script_dir"
    fi

    case "$MODE" in
        --wrappers-only)
            install_wrappers
            setup_path
            ;;
        --agent)
            install_wrappers
            install_agent_script
            setup_path
            enable_podman_socket "$os" "$runtime"
            log "Agent mode: Run 'deploy-agent.sh' to deploy Portainer Agent"
            ;;
        --server)
            install_wrappers
            install_compose "base.yml" "open-webui.yml" "port-monitor.yml"
            install_scripts
            install_agent_script
            create_data_dirs
            setup_path
            enable_podman_socket "$os" "$runtime"
            install_systemd "$os"
            ;;
        interactive|"")
            echo ""
            echo -e "${BLUE}What would you like to install?${NC}"
            echo "  1) Full server (Portainer CE + Open WebUI + port-monitor)"
            echo "  2) Agent only (Portainer Agent)"
            echo "  3) Wrappers only (docker->podman redirect)"
            echo ""
            read -rp "Choose [1/2/3]: " choice

            case "$choice" in
                1)
                    local compose_files=("base.yml")

                    read -rp "Install Open WebUI? [Y/n]: " owui
                    if [[ ! "$owui" =~ ^[Nn]$ ]]; then
                        compose_files+=("open-webui.yml")
                    fi

                    read -rp "Install port monitor? [Y/n]: " pmon
                    if [[ ! "$pmon" =~ ^[Nn]$ ]]; then
                        compose_files+=("port-monitor.yml")
                    fi

                    install_wrappers
                    install_compose "${compose_files[@]}"
                    install_scripts
                    install_agent_script
                    create_data_dirs
                    setup_path
                    enable_podman_socket "$os" "$runtime"
                    install_systemd "$os"
                    ;;
                2)
                    install_wrappers
                    install_agent_script
                    setup_path
                    enable_podman_socket "$os" "$runtime"
                    ;;
                3)
                    install_wrappers
                    setup_path
                    ;;
                *)
                    err "Invalid choice"
                    exit 1
                    ;;
            esac
            ;;
        *)
            err "Unknown mode: $MODE"
            err "Usage: install.sh [--server|--agent|--wrappers-only]"
            exit 1
            ;;
    esac

    echo ""
    log "Installation complete!"
    echo ""
    echo -e "  ${GREEN}Restart your shell or run:${NC}"
    echo -e "    source ~/.zshrc"
    echo ""
    echo -e "  ${GREEN}Start services:${NC}"
    echo -e "    ctn up"
    echo ""
    echo -e "  ${GREEN}Verify redirect:${NC}"
    echo -e "    docker --version    ${CYAN}# should show podman${NC}"
    echo -e "    docker4sure --version  ${CYAN}# should show Docker${NC}"
}

main "$@"
