#!/usr/bin/env bash
# Commercial P1/P2 automated gates for karma8.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail=0

echo "== commercial_gate: repo checks =="

need_file() {
  if [[ ! -f "$1" ]]; then
    echo "FAIL missing $1"
    fail=1
  else
    echo "OK $1"
  fi
}

need_file docs/commercial/COMMERCIAL_STANDARD.md
need_file docs/commercial/OPS_RUNBOOK.md
need_file integrations/telegram-miniapp/USER_OPS_CHECKLIST.md
need_file integrations/telegram-miniapp/COMMERCIAL_MAIN_REQUIREMENTS.md
need_file integrations/telegram-miniapp/verify_wiring.sh
need_file frontend/public/_headers
need_file deploy/nginx.economy.conf.example
need_file abi/manifest.json
need_file frontend/src/pages/LandingPage.tsx
need_file frontend/public/health.json

echo "== forge fmt --check =="
if ! forge fmt --check >/dev/null; then
  echo "FAIL forge fmt"
  fail=1
else
  echo "OK fmt"
fi

echo "== forge security suites =="
if ! forge test --match-contract SecurityHardening --quiet; then
  echo "FAIL SecurityHardening"
  fail=1
fi
if ! forge test --match-contract SecurityAuditRegression --quiet; then
  echo "FAIL SecurityAuditRegression"
  fail=1
fi
if ! forge test --match-contract GoLiveAcceptance --quiet; then
  echo "FAIL GoLiveAcceptance"
  fail=1
fi
echo "OK forge suites"

echo "== frontend typecheck =="
if [[ -d frontend/node_modules ]]; then
  if ! (cd frontend && npx tsc --noEmit); then
    echo "FAIL tsc"
    fail=1
  else
    echo "OK tsc"
  fi
else
  echo "SKIP tsc (no node_modules)"
fi

echo "== FeeBridge fee-match invariant present =="
if ! grep -q 'FeeMismatch' src/integration/FeeBridge.sol; then
  echo "FAIL FeeMismatch missing"
  fail=1
else
  echo "OK FeeMismatch"
fi

if ! grep -q 'exists' src/integration/SettlementMirror.sol; then
  echo "FAIL Mirror idempotency missing"
  fail=1
else
  echo "OK Mirror idempotency"
fi

if ! grep -q 'PrivilegedRole' src/cocreation/ContributorRegistry.sol; then
  echo "FAIL PrivilegedRole gate missing"
  fail=1
else
  echo "OK PrivilegedRole"
fi

if [[ "${ENABLE_REVENUE_CHECKS:-}" == "1" ]]; then
  echo "== P2 revenue readiness hints =="
  if [[ -z "${RPC_URL:-}" || -z "${TREASURY_ADDRESS:-}" ]]; then
    echo "FAIL P2 requires RPC_URL + TREASURY_ADDRESS"
    fail=1
  else
    rev=$(cast call "$TREASURY_ADDRESS" "enableRevenueMode()(bool)" --rpc-url "$RPC_URL" || echo err)
    echo "enableRevenueMode=$rev (operator must intentionally enable via governance)"
    echo "OK P2 env present"
  fi
fi

if [[ "$fail" -ne 0 ]]; then
  echo "RESULT: COMMERCIAL GATE FAIL"
  exit 1
fi
echo "RESULT: COMMERCIAL GATE PASS (P1 code/docs)"
echo "Reminder: P1 still needs live HTTPS + Bot + wiring + first real settle (USER_OPS_CHECKLIST)."
