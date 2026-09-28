# Elysium RPC Node

Run your own RPC node for **Elysium** in a few commands with Docker.

Elysium is an Arbitrum Orbit chain (AnyTrust) run by [Conduit](https://conduit.xyz). It settles on **HyperEVM testnet**. This repo packages an [Arbitrum Nitro](https://github.com/OffchainLabs/nitro) node already configured for Elysium. You get your own JSON-RPC (HTTP + WebSocket), with no rate limits and no third party between you and the chain.

| | |
|---|---|
| Network | Elysium testnet |
| Chain ID | `99801` |
| Parent chain | HyperEVM testnet (chain ID `998`) |
| Data availability | AnyTrust DAS (Conduit) |
| Client | `offchainlabs/nitro-node:v3.9.5-66e42c4` |

## Need an Elysium RPC?

Two options:

- **Run your own node** with this repo (see [Quick start](#quick-start)).
- **Get access to a node run by Hypedexer**: contact the Hypedexer team on Telegram, [@wsm_enigma](https://t.me/wsm_enigma).

## How it works

```
                 new blocks (feed)          ┌──────────────────────┐
Conduit sequencer ────────────────────────▶ │                      │  :8547 HTTP
                                            │   Nitro (this repo)  │  :8546 WS    ──▶ your dApp / indexer / bot
HyperEVM testnet ─── batches & proofs ────▶ │                      │  :6070 metrics
Conduit DAS ─────── batch data ───────────▶ └──────────────────────┘
```

- The node rebuilds the chain from the batches Elysium posts on HyperEVM (the parent chain), using the data in Conduit's AnyTrust DAS. It verifies everything itself.
- Once it catches up, it follows the head in real time from the Conduit sequencer feed.
- `eth_sendRawTransaction` is forwarded to the Conduit sequencer, so you can send transactions through your node.

## Requirements

- Linux x86_64 (or anything that runs `linux/amd64` containers)
- [Docker](https://docs.docker.com/engine/install/) with the Compose plugin (`docker compose version`)
- A **HyperEVM testnet RPC** with full history. The public one works but makes the first sync very slow. See [Parent chain RPC](#parent-chain-rpc).

| Resource | Minimum | Recommended |
|---|---|---|
| CPU | 2 cores | 4+ cores |
| RAM | 4 GB | 8+ GB |
| Disk | 50 GB SSD | 200 GB+ NVMe |

For scale: an archive node took about 13 GB for the first ~640k blocks (September 2026). The chain grows, so leave headroom.

## Quick start

```bash
git clone https://github.com/Enigma-Validator/elysium-rpc-node.git
cd elysium-rpc-node
cp .env.example .env        # set PARENT_CHAIN_RPC (see Parent chain RPC)
docker compose up -d --build
```

That's it. Check that it works:

```bash
./scripts/status.sh --watch       # local head vs network head
docker compose logs -f            # node logs
```

Once the status says `synced`, query it:

```bash
curl -s -X POST http://127.0.0.1:8547 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
```

| Endpoint | URL |
|---|---|
| HTTP JSON-RPC | `http://127.0.0.1:8547` |
| WebSocket | `ws://127.0.0.1:8546` |
| Prometheus metrics | `http://127.0.0.1:6070/debug/metrics/prometheus` |

If you have `make`, there are shortcuts: `make up`, `make down`, `make logs`, `make status`, `make update`.

## Configuration

Everything is in `.env`. Only `PARENT_CHAIN_RPC` matters for most people.

| Variable | Default | Description |
|---|---|---|
| `PARENT_CHAIN_RPC` | `https://rpc.hyperliquid-testnet.xyz/evm` | HyperEVM testnet RPC. **Required.** |
| `NODE_MODE` | `archive` | `archive` keeps all historical state. `full` prunes old state and uses less disk. |
| `RPC_API` | `net,web3,eth` | JSON-RPC namespaces. Add `debug` for `debug_trace*`. |
| `RPC_BIND` | `127.0.0.1` | Interface the ports are published on. `0.0.0.0` makes them reachable from the network. |
| `HTTP_PORT` / `WS_PORT` / `METRICS_PORT` | `8547` / `8546` / `6070` | Host ports. |
| `NITRO_IMAGE` | `offchainlabs/nitro-node:v3.9.5-66e42c4` | Nitro image the node is built from. |
| `FORWARDING_TARGET` | `https://rpc-elysium-testnet.t.conduit.xyz` | Where transactions are forwarded (sequencer). |
| `SEQUENCER_FEED_RELAY` | `wss://relay-elysium-testnet.t.conduit.xyz/` | Real-time block feed. |
| `DAS_URL` | `https://das-elysium-testnet.t.conduit.xyz` | AnyTrust data availability server. |
| `PARENT_CHAIN_MAX_BLOCKS_TO_READ` | `1000` | Parent-chain blocks per `eth_getLogs`. Lower it if your RPC has a smaller cap. |

After editing `.env`, apply it with `docker compose up -d`.

To pass any other [Nitro flag](https://docs.arbitrum.io/run-arbitrum-node/run-full-node), add it to the service in `docker-compose.yml`. It is appended last, so it overrides the defaults:

```yaml
    command: ["--http.api=net,web3,eth,debug", "--execution.rpc.gas-cap=100000000"]
```

### Parent chain RPC

The node reads every Elysium batch from HyperEVM testnet, starting at the block where Elysium was deployed (`63983746`). The HyperEVM RPC you use must:

- serve **history back to block 63983746** (logs and blocks), not only recent blocks;
- accept `eth_getLogs` over **1000 blocks** (or set `PARENT_CHAIN_MAX_BLOCKS_TO_READ` lower).

The public endpoint `https://rpc.hyperliquid-testnet.xyz/evm` meets both, and the node runs with it out of the box. But it is heavily rate limited per IP and often times out (HTTP 504) on log queries. The node retries these errors, so it stays correct, but **a first sync from scratch on the public RPC is very slow**: about 1,000 HyperEVM blocks per 10 minutes in our test, with ~1.5M blocks to cover since the deployment. That is days.

**For the first sync, use a HyperEVM testnet RPC that keeps full history**: your own HyperEVM node, or ask the Hypedexer team on Telegram ([@wsm_enigma](https://t.me/wsm_enigma)) for access to theirs. Once the node is synced, it only reads new HyperEVM blocks. You can then switch back to the public RPC if you want.

### Exposing the RPC publicly

By default the ports are only reachable from the machine itself. To serve other people:

1. Put a reverse proxy in front (Caddy, nginx, Traefik) for TLS and rate limiting.
2. Or set `RPC_BIND=0.0.0.0` and restrict access with a firewall.

Never expose the metrics port, and do not enable the `debug` namespace on a public endpoint without a rate limit.

## Operations

| Task | Command |
|---|---|
| Start / apply `.env` changes | `docker compose up -d --build` |
| Stop | `docker compose down` |
| Logs | `docker compose logs -f --tail 100` |
| Sync status | `./scripts/status.sh --watch` |
| Update | `git pull && docker compose up -d --build` |
| Wipe the chain data and resync | `docker compose down -v` |

Chain data lives in the Docker volume `elysium-data`, so it survives restarts and rebuilds. `docker compose down -v` deletes it.

Stopping is not instant: Nitro writes its database to disk on shutdown. Compose waits up to 5 minutes (`stop_grace_period`). Do not force-kill the container, or the database may need a resync.

## Troubleshooting

**`PARENT_CHAIN_RPC is required`**: `.env` is missing or empty. Run `cp .env.example .env`.

**Logs show `504 Gateway Timeout`, `rate limited` or `invalid block height`**: the parent chain RPC is overloaded. The node retries and moves on. If sync barely moves, switch `PARENT_CHAIN_RPC` to a better endpoint.

**`query exceeds max block range`**: your parent chain RPC caps `eth_getLogs` below 1000 blocks. Lower `PARENT_CHAIN_MAX_BLOCKS_TO_READ`.

**`missing trie node`, `header not found` or an empty `eth_getLogs` on old blocks**: your parent chain RPC has pruned its history. Use one that serves history back to block `63983746`.

**The block number stays at 0 for a while after start**: normal, especially on the public HyperEVM RPC. The node first reads the parent chain up to the first batches. Follow `docker compose logs -f` and look for `InboxTracker` and `created block` lines.

**Warnings about `validation not supported`, `P2P server will be useless` or `parent-chain-is-arbitrum is missing`**: harmless for an RPC node.

## Useful links

- Elysium public RPC (Conduit): `https://rpc-elysium-testnet.t.conduit.xyz`
- Arbitrum Nitro docs: https://docs.arbitrum.io/run-arbitrum-node/run-full-node
- Conduit's generic Orbit node repo: https://github.com/conduitxyz/conduit-arbitrum-external-node

## License

[MIT](LICENSE). Community project, not affiliated with Conduit or Hyperliquid. Provided as is, without warranty.
