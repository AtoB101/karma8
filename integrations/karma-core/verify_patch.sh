#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
UPSTREAM="$ROOT/integrations/karma-core/upstream/KarmaBilateral.sol"
PATCH_DOC="$ROOT/integrations/karma-core/PATCH.md"
DIFF="$ROOT/integrations/karma-core/patches/0001-add-treasury-feebridge.diff"

echo "==> Refresh upstream snapshot"
curl -fsSL "https://raw.githubusercontent.com/AtoB101/Karma/main/karma-core/contracts/core/KarmaBilateral.sol" \
  -o "$UPSTREAM"

echo "==> Anchor checks on upstream KarmaBilateral.sol"
grep -q "function _executeSettle(" "$UPSTREAM"
grep -q "_transfer(token, buyerOwner, buyerAmount);" "$UPSTREAM"
grep -q "_transfer(token, agentOwner, agentAmount);" "$UPSTREAM"
grep -q "function setAttestationGateway" "$UPSTREAM"
grep -q "address public immutable admin;" "$UPSTREAM"

# Ensure we are not double-patched already upstream
if grep -q "address public feeBridge;" "$UPSTREAM"; then
  echo "NOTE: upstream already contains feeBridge — patch may be integrated."
else
  echo "OK: upstream still needs feeBridge patch."
fi

test -f "$PATCH_DOC"
test -f "$DIFF"
test -f "$ROOT/src/integration/FeeBridge.sol"
test -f "$ROOT/src/integration/BilateralFeeHook.sol"

echo "==> Patch package complete"
echo "PASS"