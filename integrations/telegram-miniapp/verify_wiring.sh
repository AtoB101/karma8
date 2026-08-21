#!/usr/bin/env bash
# Verify FeeBridge ↔ Bilateral wiring + cold-start revenue flag (清单 B / G).
# Requires: cast, jq; env addresses filled.
set -euo pipefail

need() {
  local v="$1"
  if [[ -z "${!v:-}" ]]; then
    echo "missing env $v" >&2
    exit 1
  fi
}

need RPC_URL
need FEE_BRIDGE_ADDRESS
need SETTLEMENT_MIRROR_ADDRESS
need TREASURY_ADDRESS

CORE="${KARMA_BILATERAL:-${KARMA_CORE_ADDRESS:-}}"
if [[ -z "$CORE" ]]; then
  echo "missing KARMA_BILATERAL or KARMA_CORE_ADDRESS" >&2
  exit 1
fi

RPC="$RPC_URL"
fail=0

echo "== FeeBridge.core =="
core_onchain=$(cast call "$FEE_BRIDGE_ADDRESS" "core()(address)" --rpc-url "$RPC")
core_norm=$(cast --to-checksum-address "$core_onchain" 2>/dev/null || echo "$core_onchain")
expect_norm=$(cast --to-checksum-address "$CORE" 2>/dev/null || echo "$CORE")
echo "onchain: $core_onchain"
echo "expect:  $CORE"
if [[ "${core_norm,,}" != "${expect_norm,,}" ]]; then
  echo "FAIL: FeeBridge.core != Bilateral"
  fail=1
else
  echo "OK: FeeBridge.core == Bilateral"
fi

echo "== SettlementMirror.isReporter(FeeBridge) =="
is_rep=$(cast call "$SETTLEMENT_MIRROR_ADDRESS" "isReporter(address)(bool)" "$FEE_BRIDGE_ADDRESS" --rpc-url "$RPC")
echo "isReporter: $is_rep"
if [[ "$is_rep" != "true" ]]; then
  echo "FAIL: FeeBridge is not Mirror reporter"
  fail=1
else
  echo "OK: FeeBridge is reporter"
fi

echo "== Treasury.enableRevenueMode (cold-start expect false) =="
rev=$(cast call "$TREASURY_ADDRESS" "enableRevenueMode()(bool)" --rpc-url "$RPC")
echo "enableRevenueMode: $rev"

echo "== FeeBridge.quoteFeeBps(address(0)) =="
# When revenue off, quote is 0 regardless of stake tier path using address(0)/unset
bps=$(cast call "$FEE_BRIDGE_ADDRESS" "quoteFeeBps(address)(uint256)" "$CORE" --rpc-url "$RPC" || true)
echo "quoteFeeBps(developer=Bilateral-as-probe): $bps"
if [[ "$rev" == "false" ]]; then
  if [[ "$bps" != "0" ]]; then
    echo "WARN: revenueMode=false but quoteFeeBps != 0 (got $bps)"
    fail=1
  else
    echo "OK: cold-start quoteFeeBps == 0 (fee=0 still collectAndRecord on settle)"
  fi
fi

echo "== Main-repo admin checklist (manual) =="
echo "1) Bilateral.setTreasury($TREASURY_ADDRESS)"
echo "2) Bilateral.setFeeBridge($FEE_BRIDGE_ADDRESS)"
echo "3) orderId = bytes32(bindingId); developer = builder_address"
echo "4) buyer==seller → Mirror does not credit developer GMV"
echo "5) Verify PASS before settle (main); then FeeBridge.collectAndRecord"

if [[ "$fail" -ne 0 ]]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: OK"
