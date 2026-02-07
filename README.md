# docker4sure

Docker-to-Podman transparent redirect toolkit with container management.

`docker` commands are transparently forwarded to `podman`. When you need the real Docker, use `docker4sure`.

## Quick Install

```bash
# Full interactive install
curl -fsSL https://raw.githubusercontent.com/clearclown/docker4sure/main/install.sh | bash

# Or clone and run locally
git clone https://github.com/clearclown/docker4sure.git
cd docker4sure
./install.sh
```

### Install Modes

```bash
./install.sh                # Interactive setup
./install.sh --server       # Portainer CE + Open WebUI + port-monitor
./install.sh --agent        # Portainer Agent only
./install.sh --wrappers-only  # docker->podman redirect only
```

## How It Works

### Docker -> Podman Redirect

After installation, `~/.containers/bin` is prepended to your `PATH`:

```bash
docker ps          # actually runs: podman ps
docker compose up  # actually runs: podman-compose up
docker build .     # actually runs: podman build .
```

### Real Docker Access

```bash
docker4sure ps              # runs /usr/bin/docker ps
docker4sure-compose up      # runs /usr/bin/docker compose up
DOCKER_REAL=1 docker ps     # also runs real docker
```

## Container Management (`ctn`)

```bash
ctn up        # Start all services
ctn down      # Stop all services
ctn restart   # Restart all services
ctn status    # Show status + disk usage
ctn logs      # Follow logs
ctn clean     # Safe cleanup (running containers protected)
ctn nuke      # Remove everything (data dirs preserved)
ctn rebuild   # nuke + up (full rebuild)
ctn ports     # Show port usage across hosts
```

## Included Services

| Service | Port | Description |
|---------|------|-------------|
| Portainer CE | 9443 (HTTPS) | Container management UI |
| Open WebUI | 3000 | LLM chat interface (connects to LM Studio) |
| Port Monitor | 9999 | JSON API for listening ports |

## Data Persistence

All service data is stored in `~/.containers/data/` using bind mounts:

```
~/.containers/data/
  ├── open-webui/    # Chat history, settings
  ├── portainer/     # Dashboard config, users
  └── port-monitor/  # (minimal)
```

`ctn nuke` removes containers and images but **never** touches `~/.containers/data/`.
`ctn up` rebuilds everything from scratch with data intact.

## Auto Cleanup

A systemd user timer runs weekly (Sunday 03:00) to prune:
- Unused images older than 7 days
- Dangling build cache

```bash
systemctl --user status container-cleanup.timer
```

## Multi-Host Management

### Deploy Portainer Agent to Remote Hosts

```bash
~/.containers/scripts/deploy-agent.sh 100.83.54.6       # macOS
~/.containers/scripts/deploy-agent.sh 100.82.83.122      # Kali Linux
```

Then add environments in Portainer CE (https://your-host:9443).

## Uninstall

```bash
# Clone if needed, then:
./uninstall.sh

# Or manually:
rm -rf ~/.containers/bin ~/.containers/compose ~/.containers/scripts
# Remove PATH line from ~/.zshrc
# Data at ~/.containers/data/ is preserved
```

## Requirements

- **Podman** (primary) or Docker
- **podman-compose** (for compose support)
- Linux (systemd) / macOS / WSL2

## License

MIT
