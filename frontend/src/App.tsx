import { useMemo, useState } from "react";
import { StakePage } from "./pages/StakePage";
import { NodeRegisterPage } from "./pages/NodeRegisterPage";
import { GovernancePage } from "./pages/GovernancePage";
import { ContributionNftPage } from "./pages/ContributionNftPage";
import type { EconomyAddresses } from "./lib/abis";

type Tab = "stake" | "node" | "gov" | "nft";

const zero = "0x0000000000000000000000000000000000000000" as const;

function readAddresses(): EconomyAddresses {
  const env = import.meta.env;
  return {
    treasury: (env.VITE_TREASURY as `0x${string}`) || zero,
    stake: (env.VITE_STAKE as `0x${string}`) || zero,
    governor: (env.VITE_GOVERNOR as `0x${string}`) || zero,
    stakerPool: (env.VITE_STAKER_POOL as `0x${string}`) || zero,
    contributionNft: (env.VITE_CONTRIBUTION_NFT as `0x${string}`) || zero,
    karmaToken: (env.VITE_KARMA as `0x${string}`) || zero,
  };
}

export function App() {
  const [tab, setTab] = useState<Tab>("stake");
  const addresses = useMemo(() => readAddresses(), []);
  const configured = addresses.treasury !== zero;

  return (
    <div className="karma-economy" style={{ maxWidth: 960, margin: "0 auto" }}>
      <div className="karma-brand">KARMA</div>
      <h1>Economy Console</h1>
      <p>
        质押、节点、治理与贡献凭证。盈利未开启时分红与手续费减免保持锁定。
        {!configured && " 请通过 VITE_* 环境变量或 deployments/local.json 注入合约地址。"}
      </p>

      <div className="karma-row" style={{ marginBottom: "1.25rem" }}>
        {(
          [
            ["stake", "质押"],
            ["node", "节点"],
            ["gov", "治理"],
            ["nft", "贡献 NFT"],
          ] as const
        ).map(([id, label]) => (
          <button
            key={id}
            className={`karma-btn ${tab === id ? "karma-btn-primary" : "karma-btn-ghost"}`}
            onClick={() => setTab(id)}
          >
            {label}
          </button>
        ))}
      </div>

      {tab === "stake" && <StakePage addresses={addresses} />}
      {tab === "node" && <NodeRegisterPage addresses={addresses} />}
      {tab === "gov" && <GovernancePage addresses={addresses} />}
      {tab === "nft" && <ContributionNftPage addresses={addresses} />}
    </div>
  );
}