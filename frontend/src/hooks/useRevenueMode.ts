import { useReadContract } from "wagmi";
import { treasuryAbi } from "../lib/abis";

export function useRevenueMode(treasury: `0x${string}`) {
  const { data, isLoading, refetch } = useReadContract({
    address: treasury,
    abi: treasuryAbi,
    functionName: "enableRevenueMode",
  });

  return {
    enabled: Boolean(data),
    isLoading,
    refetch,
  };
}