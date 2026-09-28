#!/usr/bin/env bash
# Compares the local node head with the public Elysium RPC.
# Usage: ./scripts/status.sh [--watch]
set -euo pipefail

cd "$(dirname "$0")/.."
HTTP_PORT="$(sed -n 's/^HTTP_PORT=//p' .env 2>/dev/null | tail -1)"
LOCAL_RPC="${LOCAL_RPC:-http://127.0.0.1:${HTTP_PORT:-8547}}"
REMOTE_RPC="${REMOTE_RPC:-https://rpc-elysium-testnet.t.conduit.xyz}"

block_number() {
  local hex
  hex="$(curl -s -m 5 -X POST -H 'Content-Type: application/json' \
    --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' "$1" |
    grep -o '"result":"0x[0-9a-fA-F]*"' | cut -d'"' -f4 || true)"
  [[ -n "$hex" ]] && echo $((hex)) || echo "-"
}

show() {
  local local_head remote_head
  local_head="$(block_number "$LOCAL_RPC")"
  remote_head="$(block_number "$REMOTE_RPC")"
  printf '%s  local: %-10s  network: %-10s  ' "$(date '+%H:%M:%S')" "$local_head" "$remote_head"
  if [[ "$local_head" == "-" ]]; then
    echo "node not answering yet (docker compose logs -f)"
  elif [[ "$remote_head" == "-" ]]; then
    echo "public RPC unreachable"
  elif (( local_head >= remote_head )); then
    echo "synced"
  else
    awk -v l="$local_head" -v r="$remote_head" \
      'BEGIN { printf "syncing %.2f%% (%d blocks behind)\n", l * 100 / r, r - l }'
  fi
}

if [[ "${1:-}" == "--watch" ]]; then
  while true; do show; sleep 10; done
else
  show
fi
