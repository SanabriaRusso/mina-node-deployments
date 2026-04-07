# mina-node-deployments

A collection of different ways to deploy Mina Protocol nodes.

## Architecture Overview

```mermaid
graph TD
    subgraph entrypoint [" "]
        M["<b>Makefile</b><br><i>make up-&lt;network&gt; / down / logs / restart / ps</i>"]
    end

    M --> BASE["<b>podman-compose.yml</b><br>Base service definition<br><i>image · volumes · ports · resources</i>"]

    BASE --> |"merged with"| OVR{{"Overlay selection<br><i>per network</i>"}}

    OVR --> |"mainnet / devnet"| DAE["<b>daemon.yml</b><br>Embedded genesis<br><code>mina daemon --peer-list-url</code>"]
    OVR --> |"mesa / pre-mesa"| FULL["<b>daemon-full.yml</b><br>External genesis config<br><code>mina daemon --config-file</code><br>+ stats/error reporting"]
    OVR --> |"mainnet-uptime"| UPT["<b>daemon-uptime.yml</b><br>Uptime tracking<br><code>mina daemon --uptime-url</code><br>+ submitter key"]

    DAE  --> ENV["<b>env/&lt;network&gt;.env</b><br>MINA_IMAGE · PEER_LIST_URL<br>RUNTIME_CONFIG · NODE_STATUS_URL …"]
    FULL --> ENV
    UPT  --> ENV

    ENV --> CTR["<b>mina-daemon</b> container<br><i>12 GB RAM · 6 CPUs</i>"]

    CTR --> VOL_SHARED["<b>shared/</b><br>Genesis runtime configs<br><i>mesa · pre-mesa JSON</i>"]
    CTR --> VOL_STATE["<b>mina-*-config/</b><br>Persistent daemon state<br><i>per network</i>"]
    CTR --> VOL_OUT["<b>output/</b><br>Generated keys &amp; ledger"]

    subgraph ledger [" "]
        direction TB
        LG["<b>make ledger-gen</b><br><code>podman-compose.ledger-gen.yml</code>"]
        LG --> LGOUT["output/<br>BP keys · plain keys · genesis config"]
        LGOUT --> CK["<b>make combine-keys</b><br><code>process-keys.sh → combine-keys.sh → escape_json_key.py</code>"]
        CK --> COMB["output/combined_keys/<br>Merged key-pair JSONs"]
    end

    style entrypoint fill:none,stroke:#4a90d9,stroke-width:2px
    style ledger fill:none,stroke:#e8a838,stroke-width:2px
    style M fill:#4a90d9,color:#fff
    style BASE fill:#6baed6,color:#fff
    style DAE fill:#9ecae1,color:#000
    style FULL fill:#9ecae1,color:#000
    style UPT fill:#9ecae1,color:#000
    style ENV fill:#c6dbef,color:#000
    style CTR fill:#2ca02c,color:#fff
    style LG fill:#e8a838,color:#fff
    style OVR fill:#fff,stroke:#999
```

### Configuration Layering

Each `make up-<network>` composes three layers into a single deployment:

```
podman-compose.yml            ← base service (image, volumes, ports, resources)
  + podman-compose.<mode>.yml ← overlay (entrypoint & daemon flags per mode)
  + env/<network>.env         ← variables (image tag, peers, endpoints)
```

| Network | Overlay | Genesis | Reporting |
|---------|---------|---------|-----------|
| `mainnet` | `daemon` | Embedded in image | — |
| `devnet` | `daemon` | Embedded in image | — |
| `mesa` | `daemon-full` | External JSON in `shared/` | Stats + errors |
| `pre-mesa` | `daemon-full` | External JSON in `shared/` | Stats + errors |
| `mainnet-uptime` | `daemon-uptime` | Embedded in image | Uptime metrics |

## Deployment Methods

| Method | Description | Link |
|--------|-------------|------|
| **podman-daemon** | Podman/Docker Compose configs for running Mina daemon nodes with configurable network and mode selection | [podman-daemon/](podman-daemon/) |

## License

MIT — see [LICENSE](LICENSE).
