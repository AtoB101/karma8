import { ZERO_ADDRESS, type EconomyAddresses } from "./abis";

const z = ZERO_ADDRESS;

export function readAddresses(): EconomyAddresses {
  const env = import.meta.env;
  return {
    treasury: (env.VITE_TREASURY as `0x${string}`) || z,
    stake: (env.VITE_STAKE as `0x${string}`) || z,
    governor: (env.VITE_GOVERNOR as `0x${string}`) || z,
    stakerPool: (env.VITE_STAKER_POOL as `0x${string}`) || z,
    developerPool: (env.VITE_DEVELOPER_POOL as `0x${string}`) || z,
    contributionNft: (env.VITE_CONTRIBUTION_NFT as `0x${string}`) || z,
    karmaToken: (env.VITE_KARMA as `0x${string}`) || z,
    feeBridge: (env.VITE_FEE_BRIDGE as `0x${string}`) || z,
    settlementMirror: (env.VITE_SETTLEMENT_MIRROR as `0x${string}`) || z,
    contributorRegistry: (env.VITE_CONTRIBUTOR_REGISTRY as `0x${string}`) || z,
    contributionLedger: (env.VITE_CONTRIBUTION_LEDGER as `0x${string}`) || z,
    cocreationScore: (env.VITE_COCREATION_SCORE as `0x${string}`) || z,
    usdc: (env.VITE_USDC as `0x${string}`) || z,
    karmaBilateral: (env.VITE_KARMA_BILATERAL as `0x${string}`) || z,
  };
}

export function isConfigured(addresses: EconomyAddresses): boolean {
  return addresses.treasury !== z && addresses.feeBridge !== z;
}
