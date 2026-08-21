import { useMemo, useState } from "react";
import { useAccount, useConnect, useDisconnect, useReadContract } from "wagmi";
import { injected } from "wagmi/connectors";
import { StakePage } from "./pages/StakePage";
import { NodeRegisterPage } from "./pages/NodeRegisterPage";
import { GovernancePage } from "./pages/GovernancePage";
import { ContributionNftPage } from "./pages/ContributionNftPage";
import { MiniAppEconomyPage } from "./pages/MiniAppEconomyPage";
import { LandingPage } from "./pages/LandingPage";
import { treasuryAbi, ZERO_ADDRESS, type EconomyAddresses } from "./lib/abis";
import { isConfigured, readAddresses } from "./lib/addresses";
import { isMiniAppView } from "./lib/telegram";

type View = "landing" | "console" | "miniapp";
type Tab = "stake" | "node" | "gov" | "nft" | "status";

function initialView(): View {
  if (typeof window === "undefined") return "landing";
  const q = new URLSearchParams(window.location.search);
  if (q.get("view") === "miniapp" || isMiniAppView()) return "miniapp";
  if (q.get("view") === "console") return "console";
  return "landing";
}

function StatusPanel({ addresses }: { addresses: EconomyAddresses }) {
  const revenue = useReadContract({
    address: addresses.treasury,
    abi: treasuryAbi,
    functionName: "enableRevenueMode",
    query: { enabled: addresses.treasury !== ZERO_ADDRESS },
  });
  const fee = useReadContract({
    address: addresses.treasury,
    abi: treasuryAbi,
    functionName: "feeBps",
    query: { enabled: addresses.treasury !== ZERO_ADDRESS },
  });
  const splits = useReadContract({
    address: addresses.treasury,
    abi: treasuryAbi,
    functionName: "splitRatios",
    query: { enabled: addresses.treasury !== ZERO_ADDRESS },
  });

  return (
    <section className="karma-panel">
      <h2>上线状态 · 商业门禁</h2>
      <div className="karma-meta">
        <div>
          <span>阶段</span>
          <strong>{revenue.data ? "P2 收费" : "P1 冷启动"}</strong>
        </div>
        <div>
          <span>盈利模式</span>
          <strong>{revenue.data ? "ON" : "OFF"}</strong>
        </div>
        <div>
          <span>手续费常量</span>
          <strong>{fee.data != null ? `${fee.data.toString()} bps` : "—"}</strong>
        </div>
        <div>
          <span>分账</span>
          <strong>
            {splits.data
              ? `${splits.data[0]}/${splits.data[1]}/${splits.data[2]}/${splits.data[3]}`
              : "—"}
          </strong>
        </div>
        <div>
          <span>Treasury</span>
          <strong style={{ fontSize: "0.85rem", wordBreak: "break-all" }}>{addresses.treasury}</strong>
        </div>
        <div>
          <span>FeeBridge</span>
          <strong style={{ fontSize: "0.85rem", wordBreak: "break-all" }}>{addresses.feeBridge}</strong>
        </div>
      </div>
      <p>
        P1：fee=0 仍记 GMV。P2 须治理开启并满足 `docs/commercial/COMMERCIAL_STANDARD.md`。健康检查：
        <a href="/health.json" style={{ color: "var(--karma-accent)" }}>
          /health.json
        </a>
      </p>
    </section>
  );
}

export function App() {
  const [view, setView] = useState<View>(() => initialView());
  const [tab, setTab] = useState<Tab>("status");
  const addresses = useMemo(() => readAddresses(), []);
  const configured = isConfigured(addresses);
  const { address, isConnected } = useAccount();
  const { connect, isPending } = useConnect();
  const { disconnect } = useDisconnect();

  const go = (next: View) => {
    setView(next);
    if (typeof window !== "undefined") {
      const url = new URL(window.location.href);
      if (next === "landing") url.searchParams.delete("view");
      else url.searchParams.set("view", next === "miniapp" ? "miniapp" : "console");
      window.history.replaceState({}, "", url.toString());
    }
  };

  if (view === "landing") {
    return (
      <LandingPage
        onOpenConsole={() => go("console")}
        onOpenMiniApp={() => go("miniapp")}
      />
    );
  }

  if (view === "miniapp") {
    return (
      <>
        <div className="karma-economy" style={{ maxWidth: 960, margin: "0 auto", paddingBottom: 0 }}>
          <button className="karma-btn karma-btn-ghost" type="button" onClick={() => go("landing")}>
            ← 官网
          </button>
        </div>
        <MiniAppEconomyPage addresses={addresses} />
      </>
    );
  }

  return (
    <div className="karma-economy" style={{ maxWidth: 960, margin: "0 auto" }}>
      <div className="karma-row" style={{ justifyContent: "space-between" }}>
        <div>
          <div className="karma-brand">KARMA</div>
          <h1>Economy Console</h1>
        </div>
        <div className="karma-row">
          <button className="karma-btn karma-btn-ghost" type="button" onClick={() => go("landing")}>
            官网
          </button>
          {isConnected ? (
            <>
              <span style={{ color: "var(--karma-muted)", fontSize: "0.9rem" }}>
                {address?.slice(0, 6)}…{address?.slice(-4)}
              </span>
              <button className="karma-btn karma-btn-ghost" type="button" onClick={() => disconnect()}>
                断开
              </button>
            </>
          ) : (
            <button
              className="karma-btn karma-btn-primary"
              type="button"
              disabled={isPending}
              onClick={() => connect({ connector: injected() })}
            >
              连接钱包
            </button>
          )}
        </div>
      </div>

      <p>
        商业化控制台：质押、节点、治理与贡献。未配置地址时仅展示结构。
        {!configured && " 请同步 deployments 地址。"}
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
            type="button"
            className={`karma-btn ${tab === id ? "karma-btn-primary" : "karma-btn-ghost"}`}
            onClick={() => setTab(id)}
          >
            {label}
          </button>
        ))}
        <button className="karma-btn karma-btn-ghost" type="button" onClick={() => go("miniapp")}>
          MiniApp
        </button>
      </div>

      {tab === "status" && <StatusPanel addresses={addresses} />}
      {tab === "stake" && <StakePage addresses={addresses} />}
      {tab === "node" && <NodeRegisterPage addresses={addresses} />}
      {tab === "gov" && <GovernancePage addresses={addresses} />}
      {tab === "nft" && <ContributionNftPage addresses={addresses} />}
    </div>
  );
}
