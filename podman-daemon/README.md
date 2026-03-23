# Mina Daemon Compose Scripts

Podman/Docker Compose configurations for running Mina Protocol nodes with configurable network and mode selection.

## Quick Start

```bash
make help              # List available networks and commands
make up-mesa           # Start mesa daemon
make config-devnet     # Preview resolved devnet config
make logs-mainnet      # Follow mainnet logs
make down-mesa         # Stop mesa daemon
```

## Structure

```
podman-daemon/
├── Makefile                            # Network-aware compose runner
├── podman-compose.yml                  # Base configuration (required)
├── podman-compose.daemon.yml           # Mode: Simple daemon (embedded genesis)
├── podman-compose.daemon-full.yml      # Mode: Full daemon with external genesis config
├── podman-compose.daemon-uptime.yml    # Mode: Daemon with uptime tracking
├── podman-compose.ledger-gen.yml       # Mode: Ledger generation script
├── env/
│   ├── mainnet.env                     # Network: Mainnet
│   ├── mainnet-uptime.env              # Network: Mainnet + uptime reporting
│   ├── devnet.env                      # Network: Devnet
│   ├── mesa.env                        # Network: Mesa testnet
│   └── pre-mesa.env                    # Network: Pre-Mesa testnet
└── shared/
    ├── mina_mesa_big_runtime_config.json
    └── mina_pre_mesa_1_config.json
```

## Configuration

### Networks

| Network | Overlay | Env File | Notes |
|---------|---------|----------|-------|
| Mesa | `daemon-full` | `env/mesa.env` | External genesis config |
| Pre-Mesa | `daemon-full` | `env/pre-mesa.env` | External genesis config |
| Devnet | `daemon` | `env/devnet.env` | Genesis embedded in image |
| Mainnet | `daemon` | `env/mainnet.env` | Genesis embedded in image |
| Mainnet + Uptime | `daemon-uptime` | `env/mainnet-uptime.env` | Uptime reporting to Cloud Function |

### Modes (override files)

| Mode | Override File | Description |
|------|---------------|-------------|
| daemon | `podman-compose.daemon.yml` | Simple daemon using `--peer-list-url` |
| daemon-full | `podman-compose.daemon-full.yml` | Full daemon with `--config-file` for external genesis, stats, and status URLs |
| daemon-uptime | `podman-compose.daemon-uptime.yml` | Daemon with uptime key and reporting |
| ledger-gen | `podman-compose.ledger-gen.yml` | Ledger generation script for hard fork dry runs |

## Usage

The Makefile handles compose file layering and env file selection automatically:

```bash
make up-<network>       # Start daemon (detached)
make down-<network>     # Stop and remove daemon
make logs-<network>     # Tail daemon logs
make config-<network>   # Print resolved compose config
make restart-<network>  # Restart daemon
make ps-<network>       # Show running containers
```

### Manual Invocation

You can also invoke podman-compose directly:

```bash
podman-compose --env-file env/<network>.env \
               -f podman-compose.yml \
               -f podman-compose.<mode>.yml \
               up -d
```

## Adding a New Network

1. Create `env/<network>.env`:

```env
MINA_IMAGE=<container-image>
PEER=<peer-multiaddr>
RUNTIME_CONFIG=<config-file-name>
PEER_LIST_URL=<peer-list-url>
NODE_STATUS_URL=<status-url>
NODE_ERROR_URL=<error-url>
MINA_CONFIG_DIR=./mina-<network>-config
```

2. Add to the Makefile registry:

```makefile
NETWORKS := ... <network>
OVERLAY_<network> := daemon   # or daemon-full if external genesis config is needed
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `MINA_IMAGE` | Yes | Container image for mina-daemon |
| `PEER` | No | Peer multiaddress for direct node connection |
| `PEER_LIST_URL` | No | URL to fetch peer list |
| `RUNTIME_CONFIG` | No | Runtime config file name (in `./shared/`) |
| `NODE_STATUS_URL` | No | URL for node status reporting |
| `NODE_ERROR_URL` | No | URL for error reporting |
| `MINA_CONFIG_DIR` | No | Host path for persistent `.mina-config` (default: `./mina-config`) |

## Volume Mounts

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `~/github/mina` | `/app` (ro) | Mina source code |
| `./output` | `/output` (rw) | Script outputs |
| `./shared` | `/shared` (rw) | Shared configs (genesis/runtime) |
| `${MINA_CONFIG_DIR}` | `/root/.mina-config` (rw) | Persistent daemon state (per-network) |

## Resources

Default resource limits (fixed across all configurations):
- Memory: 12G (limit and reservation)
- CPUs: 6.00 (limit and reservation)
