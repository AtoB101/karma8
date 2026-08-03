#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
UPSTREAM="$ROOT/integrations/karma-core/upstream/KarmaBilateral.sol"
PATCH_DOC="$ROOT/integrations/karma-core/PATCH.md"
DIFF="$ROOT/integrations/karma-core/patches/0001-add-treasury-feebridge.diff"
APPLY_DOC="$ROOT/integrations/karma-core/APPLY.md"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> Refresh upstream snapshot"
curl -fsSL "https://raw.githubusercontent.com/AtoB101/Karma/main/karma-core/contracts/core/KarmaBilateral.sol" \
  -o "$UPSTREAM"

echo "==> Anchor checks on upstream KarmaBilateral.sol"
grep -q "function _executeSettle(" "$UPSTREAM"
grep -q "_transfer(token, buyerOwner, buyerAmount);" "$UPSTREAM"
grep -q "_transfer(token, agentOwner, agentAmount);" "$UPSTREAM"
grep -q "function setAttestationGateway" "$UPSTREAM"
grep -q "address public immutable admin;" "$UPSTREAM"

# Ensure package files exist
test -f "$PATCH_DOC"
test -f "$APPLY_DOC"
test -f "$DIFF"
test -f "$ROOT/src/integration/FeeBridge.sol"
test -f "$ROOT/src/integration/BilateralFeeHook.sol"
test -f "$ROOT/src/integration/SettlementMirror.sol"
test -f "$ROOT/src/integration/CoreEscrowAdapter.sol"
test -f "$ROOT/script/WireKarmaCore.s.sol"

if grep -q "address public feeBridge;" "$UPSTREAM"; then
  echo "NOTE: upstream already contains feeBridge — patch may be integrated."
  echo "PASS (upstream integrated)"
  exit 0
fi

echo "==> git apply --check against fresh upstream tree layout"
mkdir -p "$TMP/karma-core/contracts/core"
cp "$UPSTREAM" "$TMP/karma-core/contracts/core/KarmaBilateral.sol"
# Seed a git repo so git apply can use index metadata when present; fall back to --unsafe-paths
(
  cd "$TMP"
  git init -q
  git add karma-core/contracts/core/KarmaBilateral.sol
  git -c user.email=verify@patch -c user.name=verify commit -q -m "upstream"
  git apply --check "$DIFF"
  git apply "$DIFF"
  grep -q "address public feeBridge;" karma-core/contracts/core/KarmaBilateral.sol
  grep -q "function _collectEconomyFee(" karma-core/contracts/core/KarmaBilateral.sol
  grep -q "function setFeeBridge(" karma-core/contracts/core/KarmaBilateral.sol
)

echo "==> Patch package complete (applyable + economy bridge present)"
echo "PASS"
