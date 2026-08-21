#!/usr/bin/env bash
# Export forge ABIs used by MiniApp / main BFF into abi/*.json
# Frontend typed subset remains frontend/src/lib/abis.ts — keep names aligned.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -d out ]]; then
  forge build
fi

mkdir -p abi

copy_abi() {
  local artifact="$1"
  local name="$2"
  local src="out/${artifact}/${name}.json"
  if [[ ! -f "$src" ]]; then
    echo "missing $src — run forge build" >&2
    exit 1
  fi
  jq '{contractName: .contractName, abi: .abi}' "$src" > "abi/${name}.json"
  echo "wrote abi/${name}.json"
}

copy_abi Treasury.sol Treasury
copy_abi FeeBridge.sol FeeBridge
copy_abi SettlementMirror.sol SettlementMirror
copy_abi MultiTierStake.sol MultiTierStake
copy_abi StakerRewardPool.sol StakerRewardPool
copy_abi DeveloperRewardPool.sol DeveloperRewardPool
copy_abi ContributionNFT.sol ContributionNFT
copy_abi ContributorRegistry.sol ContributorRegistry
copy_abi ContributionLedger.sol ContributionLedger
copy_abi CocreationScoreView.sol CocreationScoreView
copy_abi KarmaToken.sol KarmaToken
copy_abi KarmaGovernor.sol KarmaGovernor

# Manifest for main BFF (paths relative to repo root)
jq -n \
  --arg aligned "frontend/src/lib/abis.ts" \
  '{
    alignedFrontendAbi: $aligned,
    files: [
      "abi/Treasury.json",
      "abi/FeeBridge.json",
      "abi/SettlementMirror.json",
      "abi/MultiTierStake.json",
      "abi/StakerRewardPool.json",
      "abi/DeveloperRewardPool.json",
      "abi/ContributionNFT.json",
      "abi/ContributorRegistry.json",
      "abi/ContributionLedger.json",
      "abi/CocreationScoreView.json",
      "abi/KarmaToken.json",
      "abi/KarmaGovernor.json"
    ],
    notes: "Use abis.ts for MiniApp; use abi/*.json for BFF eth_call / codegen."
  }' > abi/manifest.json

echo "OK — abi/manifest.json"
echo "Frontend subset: frontend/src/lib/abis.ts"
