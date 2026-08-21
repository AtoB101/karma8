import { getAddress, isAddress, type Address } from "viem";
import { ZERO_ADDRESS, type EconomyAddresses } from "./abis";

const z = ZERO_ADDRESS;

function parseAddr(raw: unknown): Address {
  if (typeof raw !== "string" || raw.length === 0) return z;
  if (!isAddress(raw)) return z;
  try {
    return getAddress(raw);
  } catch {
    return z;
  }
}

export function readAddresses(): EconomyAddresses {
  const env = import.meta.env;
  return {
    treasury: parseAddr(env.VITE_TREASURY),
    stake: parseAddr(env.VITE_STAKE),
    governor: parseAddr(env.VITE_GOVERNOR),
    stakerPool: parseAddr(env.VITE_STAKER_POOL),
    developerPool: parseAddr(env.VITE_DEVELOPER_POOL),
    contributionNft: parseAddr(env.VITE_CONTRIBUTION_NFT),
    karmaToken: parseAddr(env.VITE_KARMA),
    feeBridge: parseAddr(env.VITE_FEE_BRIDGE),
    settlementMirror: parseAddr(env.VITE_SETTLEMENT_MIRROR),
    contributorRegistry: parseAddr(env.VITE_CONTRIBUTOR_REGISTRY),
    contributionLedger: parseAddr(env.VITE_CONTRIBUTION_LEDGER),
    cocreationScore: parseAddr(env.VITE_COCREATION_SCORE),
    usdc: parseAddr(env.VITE_USDC),
    karmaBilateral: parseAddr(env.VITE_KARMA_BILATERAL),
  };
}

export function isConfigured(addresses: EconomyAddresses): boolean {
  return addresses.treasury !== z && addresses.feeBridge !== z && addresses.stake !== z;
}

/** Expected chain from env (default anvil). */
export function expectedChainId(): number {
  const n = Number(import.meta.env.VITE_CHAIN_ID || 31337);
  return Number.isFinite(n) ? n : 31337;
}

/** Gate wallet writes: configured + wallet on expected chain. */
export function assertCanWrite(addresses: EconomyAddresses, chainId: number | undefined): string | null {
  if (!isConfigured(addresses)) return "合约地址未配置";
  if (chainId == null) return "钱包未连接网络";
  if (chainId !== expectedChainId()) {
    return `请切换到 chainId ${expectedChainId()}（当前 ${chainId}）`;
  }
  return null;
}
