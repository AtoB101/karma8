import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { WagmiProvider, createConfig, http } from "wagmi";
import { injected } from "wagmi/connectors";
import { foundry, sepolia, mainnet } from "wagmi/chains";
import type { ReactNode } from "react";

const queryClient = new QueryClient();

const rpc = (import.meta.env.VITE_RPC_URL as string) || undefined;
const chainId = Number(import.meta.env.VITE_CHAIN_ID || 31337);

const transports = {
  [foundry.id]: http(rpc || "http://127.0.0.1:8545"),
  [sepolia.id]: http(rpc || undefined),
  [mainnet.id]: http(rpc || undefined),
} as const;

const chains =
  chainId === 1 ? ([mainnet, sepolia, foundry] as const) : chainId === 11155111 ? ([sepolia, foundry] as const) : ([foundry, sepolia] as const);

const config = createConfig({
  chains,
  connectors: [injected()],
  transports,
});

export function AppProviders({ children }: { children: ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </WagmiProvider>
  );
}
