# Mina Daemon Compose Scripts

Podman/Docker Compose configurations for running Mina Protocol nodes with configurable network and mode selection.

## Quick Start

```bash
# Run mainnet node with simple daemon
podman-compose --env-file env/mainnet.env -f podman-compose.yml -f podman-compose.daemon.yml up
```

## Structure

```
podman-daemon/
├── podman-compose.yml              # Base configuration (required)
├── podman-compose.daemon.yml       # Mode: Simple daemon
├── podman-compose.daemon-full.yml  # Mode: Full daemon with stats/status
├── podman-compose.ledger-gen.yml   # Mode: Ledger generation script
└── env/
    ├── mainnet.env                 # Network: Mainnet
    └── mesa.env                    # Network: Mesa testnet
```

## Configuration

### Networks (env files)

| Network | Env File | Description |
|---------|----------|-------------|
| Mainnet | `env/mainnet.env` | Production mainnet |
| Devnet | `env/devnet.env` | Production devnet |
| Mesa | `env/mesa.env` | Mesa testnet/devnet |

### Modes (override files)

| Mode | Override File | Description |
|------|---------------|-------------|
| daemon | `podman-compose.daemon.yml` | Simple daemon with `--peer` flag |
| daemon-full | `podman-compose.daemon-full.yml` | Full daemon with config file, stats, and status URLs |
| ledger-gen | `podman-compose.ledger-gen.yml` | Ledger generation script for hard fork dry runs |

## Usage

Combine one **env file** (network) with one **override file** (mode):

```bash
podman-compose --env-file env/<network>.env \
               -f podman-compose.yml \
               -f podman-compose.<mode>.yml \
               up
```

### Examples

```bash
# Mainnet - simple daemon
podman-compose --env-file env/mainnet.env -f podman-compose.yml -f podman-compose.daemon.yml up

# Mesa - simple daemon
podman-compose --env-file env/mesa.env -f podman-compose.yml -f podman-compose.daemon.yml up

# Mainnet - full daemon with stats
podman-compose --env-file env/mainnet.env -f podman-compose.yml -f podman-compose.daemon-full.yml up

# Mesa - full daemon with stats
podman-compose --env-file env/mesa.env -f podman-compose.yml -f podman-compose.daemon-full.yml up

# Mesa - ledger generation
podman-compose --env-file env/mesa.env -f podman-compose.yml -f podman-compose.ledger-gen.yml up
```

### Common Operations

```bash
# Run in background
podman-compose --env-file env/mainnet.env -f podman-compose.yml -f podman-compose.daemon.yml up -d

# View logs
podman-compose --env-file env/mainnet.env -f podman-compose.yml -f podman-compose.daemon.yml logs -f

# Stop
podman-compose --env-file env/mainnet.env -f podman-compose.yml -f podman-compose.daemon.yml down

# Validate configuration (dry run)
podman-compose --env-file env/mainnet.env -f podman-compose.yml -f podman-compose.daemon.yml config
```

## Adding a New Network

1. Create a new env file `env/<network>.env`:

```env
MINA_IMAGE=<container-image>
PEER=<peer-multiaddr>
RUNTIME_CONFIG=<config-file-name>
PEER_LIST_URL=<peer-list-url>
NODE_STATUS_URL=<status-url>
NODE_ERROR_URL=<error-url>
```

2. Use with any existing mode:

```bash
podman-compose --env-file env/<network>.env -f podman-compose.yml -f podman-compose.daemon.yml up
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `MINA_IMAGE` | Yes | Container image for mina-daemon |
| `PEER` | Yes | Peer multiaddress for node connection |
| `RUNTIME_CONFIG` | No | Runtime config file name (in `./shared/`) |
| `PEER_LIST_URL` | No | URL to fetch peer list |
| `NODE_STATUS_URL` | No | URL for node status reporting |
| `NODE_ERROR_URL` | No | URL for error reporting |

## Volume Mounts

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `~/github/mina` | `/app` (ro) | Mina source code |
| `./output` | `/output` (rw) | Script outputs |
| `./shared` | `/shared` (rw) | Shared configs |

## Resources

Default resource limits (fixed across all configurations):
- Memory: 12G (limit and reservation)
- CPUs: 6.00 (limit and reservation)
