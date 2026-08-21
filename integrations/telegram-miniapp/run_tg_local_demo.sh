#!/usr/bin/env bash
# One-shot local Telegram multi-scenario demo (anvil + economy + MiniApp seed).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

ANVIL_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
RPC=http://127.0.0.1:8545
SESSION=karma8-anvil

start_anvil() {
  if [[ "${RESET_ANVIL:-}" == "1" ]]; then
    tmux -f /exec-daemon/tmux.portal.conf has-session -t "=$SESSION" 2>/dev/null \
      && tmux -f /exec-daemon/tmux.portal.conf kill-session -t "$SESSION" || true
    pkill -f 'anvil --chain-id 31337' 2>/dev/null || true
    sleep 1
  fi
  if curl -s -X POST -H 'content-type: application/json' \
    --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' "$RPC" | grep -q 0x7a69; then
    echo "anvil already on $RPC"
    return
  fi
  tmux -f /exec-daemon/tmux.portal.conf has-session -t "=$SESSION" 2>/dev/null \
    || tmux -f /exec-daemon/tmux.portal.conf new-session -d -s "$SESSION" -c "$ROOT" -- \
      anvil --chain-id 31337 --host 0.0.0.0 --port 8545
  for i in $(seq 1 40); do
    if curl -s -X POST -H 'content-type: application/json' \
      --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' "$RPC" | grep -q 0x7a69; then
      echo "anvil ready"
      return
    fi
    sleep 0.25
  done
  echo "anvil failed to start" >&2
  exit 1
}

start_anvil

echo "== DeployLocalDemo =="
forge script script/DeployLocalDemo.s.sol:DeployLocalDemo \
  --rpc-url "$RPC" --broadcast --private-key "$ANVIL_KEY" -vv

echo "== SeedTelegramScenarios =="
forge script script/SeedTelegramScenarios.s.sol:SeedTelegramScenarios \
  --rpc-url "$RPC" --broadcast --private-key "$ANVIL_KEY" -vv

echo "== Sync frontend env =="
if [[ -f deployments/local.json ]]; then
  # ensure rpcUrl for wagmi
  tmp=$(mktemp)
  jq '.rpcUrl = "http://127.0.0.1:8545" | .economyHost = "http://127.0.0.1:5173"' \
    deployments/local.json > "$tmp" && mv "$tmp" deployments/local.json
fi
(cd frontend && npm run sync-addresses -- local)

echo "== Write economy-surface.json =="
node scripts/write_economy_surface.mjs local

echo "== verify wiring =="
export RPC_URL="$RPC"
export FEE_BRIDGE_ADDRESS="$(jq -r .feeBridge deployments/local.json)"
export SETTLEMENT_MIRROR_ADDRESS="$(jq -r .settlementMirror deployments/local.json)"
export TREASURY_ADDRESS="$(jq -r .treasury deployments/local.json)"
export KARMA_BILATERAL="$(jq -r .karmaBilateral deployments/local.json)"
bash integrations/telegram-miniapp/verify_wiring.sh

cat <<EOF

========================================
Telegram multi-scenario local demo ready
========================================
RPC:     $RPC  (chainId 31337)
MiniApp: http://127.0.0.1:5173/?view=miniapp
TG shell mock: http://127.0.0.1:5173/tg-shell.html
Surface: http://127.0.0.1:5173/economy-surface.json
Scenarios: deployments/scenarios.json

MetaMask: add Localhost 8545, import anvil #0 key, open MiniApp.

Real Telegram:
  1) tunnel frontend (cloudflared/ngrok) → HTTPS
  2) set KARMA8_ECONOMY_HOST to that HTTPS origin
  3) main MiniApp iframe / MenuButton → \$HOST/?view=miniapp
  See integrations/telegram-miniapp/TELEGRAM_SCENARIOS.md

Start UI:
  cd frontend && npm run dev
========================================
EOF
