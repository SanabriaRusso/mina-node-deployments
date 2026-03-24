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
├── combine-keys.sh                     # Utility: Merge private+public keys into JSON
├── escape_json_key.py                  # Utility: Escape JSON key field for daemon
├── env/
│   ├── mainnet.env                     # Network: Mainnet
│   ├── mainnet-uptime.env              # Network: Mainnet + uptime reporting
│   ├── devnet.env                      # Network: Devnet
│   ├── mesa.env                        # Network: Mesa testnet
│   └── pre-mesa.env                    # Network: Pre-Mesa testnet
├── shared/                             # Runtime configs (genesis/runtime)
└── output/                             # Generated ledger files (gitignored)
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

## Ledger Generation

The `ledger-gen` mode runs a hard fork dry-run script that generates a genesis ledger with block producer keys and funded accounts. This is used to bootstrap testnets where multiple users need to produce blocks.

### How It Works

The script (`generate-ledger-hf-dryrun.sh` inside the container) takes the top mainnet stakers and replaces them with newly generated block producer keypairs. These BP accounts inherit the delegated stake from the original stakers, making them eligible to produce blocks immediately on the new network.

### Running

```bash
make ledger-gen                             # Generate ledger using devnet env (default)
make ledger-gen LEDGER_PREFIX=my-testnet    # Override output prefix
make ledger-gen LEDGER_NETWORK=mesa         # Use a different network env
make ledger-gen-config                      # Preview resolved compose config
make ledger-gen-down                        # Clean up container after run
```

The target runs in the foreground (no `-d`) since ledger generation is a one-shot job.

### Genesis Timestamp

The upstream `generate-ledger-hf-dryrun.sh` script uses GNU `date` to compute a default genesis timestamp, which fails on macOS. To work around this, the Makefile generates `GENESIS_TIMESTAMP` locally using macOS-compatible `date` (next full hour, UTC) and the compose entrypoint patches the script before execution.

Override manually if needed:

```bash
make ledger-gen GENESIS_TIMESTAMP=2026-04-01T14:00:00Z
```

### Script Parameters

These are configured in `podman-compose.ledger-gen.yml`:

| Flag | Value | Description |
|------|-------|-------------|
| `-p` | 20 | **Block producer keys.** Replaces the top N mainnet stakers; each inherits delegated stake |
| `-k` | 30 | **Plain keys.** Total non-BP keypairs generated for general testing |
| `-e` | 5 | **Extra funded keys.** How many of the plain keys receive the `-b` balance (must be <= `-k`) |
| `-b` | 7000000 | **Balance.** MINA assigned to each extra funded key |
| `--pad-app-state` | — | Pads the app state in the generated ledger |
| `--timestamp` | `${GENESIS_TIMESTAMP}` | Genesis timestamp (generated by Makefile, macOS-compatible) |
| `--prefix` | `${LEDGER_PREFIX:-new-devnet}` | Filename prefix for all generated output files |

The remaining flags (`--mina-binary`, `--runtime-genesis-ledger-binary`, `--output-dir`) are container paths and should not need changes.

### Output

Generated files are written to `./output/` on the host. Expect:

- **BP keypairs:** `<prefix>-bp1` through `<prefix>-bp20` (private keys) and corresponding `.pub` files
- **Plain keypairs:** `<prefix>-key1` through `<prefix>-key30` and `.pub` files
- **Runtime config:** Updated genesis ledger config with all BP public keys inserted

### Post-Generation: Preparing Keys

Two utility scripts help convert raw keypairs into the JSON format needed by the Mina daemon:

**1. Combine private + public key into a single JSON file:**

```bash
./combine-keys.sh output/<prefix>-bp1 output/<prefix>-bp1.pub output/bp1.json
```

This produces: `{"key": <private_key>, "pub": "<public_key>"}`

**2. Escape the JSON key field for daemon compatibility:**

```bash
python escape_json_key.py output/bp1.json -o output/bp1-escaped.json
```

### Tuning for Your Testnet

| Scenario | Recommended changes |
|----------|-------------------|
| Small local test (1-2 producers) | `-p 2 -k 6 -e 2` |
| Multi-user testnet (current) | `-p 20 -k 30 -e 5` |
| Large-scale testnet | Increase `-p` to match participant count, scale `-k` proportionally |

When changing `-p`, keep in mind that each BP replaces a top mainnet staker. The number of BPs determines how many independent users can produce blocks on the testnet.

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
