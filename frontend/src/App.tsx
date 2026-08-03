import { useMemo, useState } from "react";
import { useAccount, useConnect, useDisconnect, useReadContract } from "wagmi";
import { injected } from "wagmi/connectors";
import { StakePage } from "./pages/StakePage";
import { NodeRegisterPage } from "./pages/NodeRegisterPage";
import { GovernancePage } from "./pages/GovernancePage";
import { ContributionNftPage } from "./pages/ContributionNftPage";
import { treasuryAbi, type EconomyAddresses } from "./lib/abis";

type Tab = "stake" | "node" | "gov" | "nft" | "status";

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

function StatusPanel({ addresses }: { addresses: EconomyAddresses }) {
  const revenue = useReadContract({
    address: addresses.treasury,
    abi: treasuryAbi,
    functionName: "enableRevenueMode",
    query: { enabled: addresses.treasury !== zero },
  });
  const fee = useReadContract({
    address: addresses.treasury,
    abi: treasuryAbi,
    functionName: "feeBps",
    query: { enabled: addresses.treasury !== zero },
  });
  const splits = useReadContract({
    address: addresses.treasury,
    abi: treasuryAbi,
    functionName: "splitRatios",
    query: { enabled: addresses.treasury !== zero },
  });

  return (
    <section className="karma-panel">
      <h2>上线状态</h2>
      <div className="karma-meta">
        <div>
          <span>盈利模式</span>
          <strong>{revenue.data ? "ON" : "OFF（冷启动）"}</strong>
        </div>
        <div>
          <span>手续费</span>
          <strong>{fee.data?.toString() ?? "20"} bps</strong>
        </div>
        <div>
          <span>分账</span>
          <strong>
            {splits.data
              ? `${splits.data[0]}/${splits.data[1]}/${splits.data[2]}/${splits.data[3]}`
              : "40/30/20/10"}
          </strong>
        </div>
        <div>
          <span>Treasury</span>
          <strong style={{ fontSize: "0.85rem", wordBreak: "break-all" }}>{addresses.treasury}</strong>
        </div>
      </div>
      <p>冷启动阶段保持 OFF；治理投票通过后再开启飞轮。费率与分账链上不可变。</p>
    </section>
  );
}

export function App() {
  const [tab, setTab] = useState<Tab>("status");
  const addresses = useMemo(() => readAddresses(), []);
  const configured = addresses.treasury !== zero;
  const { address, isConnected } = useAccount();
  const { connect, isPending } = useConnect();
  const { disconnect } = useDisconnect();

  return (
    <div className="karma-economy" style={{ maxWidth: 960, margin: "0 auto" }}>
      <div className="karma-row" style={{ justifyContent: "space-between" }}>
        <div>
          <div className="karma-brand">KARMA</div>
          <h1>Economy Console</h1>
        </div>
        <div className="karma-row">
          {isConnected ? (
            <>
              <span style={{ color: "var(--karma-muted)", fontSize: "0.9rem" }}>
                {address?.slice(0, 6)}…{address?.slice(-4)}
              </span>
              <button className="karma-btn karma-btn-ghost" onClick={() => disconnect()}>
                断开
              </button>
            </>
          ) : (
            <button
              className="karma-btn karma-btn-primary"
              disabled={isPending}
              onClick={() => connect({ connector: injected() })}
            >
              连接钱包
            </button>
          )}
        </div>
      </div>

      <p>
        质押、节点、治理与贡献凭证控制台。盈利未开启时分红与手续费减免锁定。
        {!configured && " 请配置 VITE_TREASURY 等环境变量（可由 deployments/local.json 导入）。"}
      </p>

      <div className="karma-row" style={{ marginBottom: "1.25rem" }}>
        {(
          [
            ["status", "状态"],
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

      {tab === "status" && <StatusPanel addresses={addresses} />}
      {tab === "stake" && <StakePage addresses={addresses} />}
      {tab === "node" && <NodeRegisterPage addresses={addresses} />}
      {tab === "gov" && <GovernancePage addresses={addresses} />}
      {tab === "nft" && <ContributionNftPage addresses={addresses} />}
    </div>
  );
}