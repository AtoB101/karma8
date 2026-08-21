import { useAccount, useChainId } from "wagmi";
import type { EconomyAddresses } from "../lib/abis";
import { assertCanWrite } from "../lib/addresses";

export function useWriteGate(addresses: EconomyAddresses): {
  canWrite: boolean;
  reason: string | null;
} {
  const { isConnected } = useAccount();
  const chainId = useChainId();
  if (!isConnected) return { canWrite: false, reason: "请先连接钱包" };
  const reason = assertCanWrite(addresses, chainId);
  return { canWrite: reason == null, reason };
}
