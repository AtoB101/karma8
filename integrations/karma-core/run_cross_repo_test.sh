#!/usr/bin/env bash
# End-to-end: live AtoB101/Karma KarmaBilateral x this repo's FeeBridge/Treasury/Mirror.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORKDIR="${TMPDIR:-/tmp}/karma8-cross-repo-$$"
KARMA_REF="${KARMA_REF:-main}"
export PATH="${HOME}/.foundry/bin:${PATH}"

cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

echo "==> Clone AtoB101/Karma@${KARMA_REF}"
git clone --depth 1 --branch "$KARMA_REF" https://github.com/AtoB101/Karma.git "$WORKDIR/karma"

echo "==> Assert upstream feeBridge surface"
grep -q "address public feeBridge" "$WORKDIR/karma/karma-core/contracts/core/KarmaBilateral.sol"
grep -q "function _collectEconomyFee" "$WORKDIR/karma/karma-core/contracts/core/KarmaBilateral.sol"
grep -q "function setFeeBridge" "$WORKDIR/karma/karma-core/contracts/core/KarmaBilateral.sol"

echo "==> Materialize forge harness"
mkdir -p "$WORKDIR/harness/test" "$WORKDIR/harness/src"
ln -s "$ROOT/lib/forge-std" "$WORKDIR/harness/lib-forge-std"
ln -s "$ROOT/lib/openzeppelin-contracts" "$WORKDIR/harness/lib-oz"
ln -s "$ROOT/src" "$WORKDIR/harness/economy-src"
ln -s "$WORKDIR/karma/karma-core/contracts" "$WORKDIR/harness/karma-contracts"

cat > "$WORKDIR/harness/foundry.toml" <<'EOF'
[profile.default]
src = "src"
test = "test"
out = "out"
libs = []
solc_version = "0.8.24"
optimizer = true
optimizer_runs = 200
via_ir = true
remappings = [
  "@openzeppelin/contracts/=lib-oz/contracts/",
  "forge-std/=lib-forge-std/src/",
  "economy/=economy-src/",
  "karma/=karma-contracts/",
]
EOF

echo '// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
contract Placeholder {}' > "$WORKDIR/harness/src/Placeholder.sol"

cp "$ROOT/integrations/karma-core/CrossRepoFeeBridge.t.sol" "$WORKDIR/harness/test/CrossRepoFeeBridge.t.sol"

echo "==> forge test (live Bilateral x FeeBridge)"
(
  cd "$WORKDIR/harness"
  forge test -vv
)

echo "PASS"
