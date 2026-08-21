import { useEffect, useMemo, useState } from "react";
import { formatEther, formatUnits } from "viem";
import { useAccount, useConnect, useDisconnect, useReadContract, useWriteContract } from "wagmi";
import { injected } from "wagmi/connectors";
import {
  ROLE,
  TIER,
  ZERO_ADDRESS,
  contributionLedgerAbi,
  contributionNftAbi,
  contributorRegistryAbi,
  developerPoolAbi,
  feeBridgeAbi,
  settlementMirrorAbi,
  stakeAbi,
  stakerPoolAbi,
  treasuryAbi,
  type EconomyAddresses,
} from "../lib/abis";
import { bootstrapTelegramWebApp } from "../lib/telegram";
import { useRevenueMode } from "../hooks/useRevenueMode";
import "../styles/economy.css";

type SubTab = "status" | "wallet" | "rewards" | "contrib";

const TIER_LABEL: Record<number, string> = {
  [TIER.None]: "未质押",
  [TIER.Public]: "大众",
  [TIER.Developer]: "开发者",
  [TIER.Verifier]: "仲裁节点",
  [TIER.Partner]: "合伙人",
};

type Props = { addresses: EconomyAddresses };

export function MiniAppEconomyPage({ addresses }: Props) {
  const [tab, setTab] = useState<SubTab>(() => {
    if (typeof window === "undefined") return "status";
    const t = new URLSearchParams(window.location.search).get("tab");
    if (t === "wallet" || t === "rewards" || t === "contrib" || t === "status") return t;
    return "status";
  });

  const tg = useMemo(() => bootstrapTelegramWebApp(), []);
  const tgUser = tg?.initDataUnsafe?.user;
  const { address, isConnected } = useAccount();
  const { connect, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const { enabled: revenueOn } = useRevenueMode(addresses.treasury);
  const { writeContract, isPending: claiming } = useWriteContract();

  useEffect(() => {
    document.documentElement.classList.add("karma-miniapp");
    return () => document.documentElement.classList.remove("karma-miniapp");
  }, []);

  const enabled = Boolean(address) && addresses.treasury !== ZERO_ADDRESS;

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
  const tier = useReadContract({
    address: addresses.stake,
    abi: stakeAbi,
    functionName: "tierOf",
    args: address ? [address] : undefined,
    query: { enabled },
  });
  const stakeOf = useReadContract({
    address: addresses.stake,
    abi: stakeAbi,
    functionName: "stakeOf",
    args: address ? [address] : undefined,
    query: { enabled },
  });
  const feeFor = useReadContract({
    address: addresses.stake,
    abi: stakeAbi,
    functionName: "feeBpsFor",
    args: address ? [address] : undefined,
    query: { enabled },
  });
  const earned = useReadContract({
    address: addresses.stakerPool,
    abi: stakerPoolAbi,
    functionName: "earned",
    args: address ? [address] : undefined,
    query: { enabled: enabled && addresses.stakerPool !== ZERO_ADDRESS },
  });
  const nftWeight = useReadContract({
    address: addresses.contributionNft,
    abi: contributionNftAbi,
    functionName: "totalWeightOf",
    args: address ? [address] : undefined,
    query: { enabled: enabled && addresses.contributionNft !== ZERO_ADDRESS },
  });
  const pendingMint = useReadContract({
    address: addresses.contributionLedger,
    abi: contributionLedgerAbi,
    functionName: "pendingMintWeight",
    args: address ? [address] : undefined,
    query: { enabled: enabled && addresses.contributionLedger !== ZERO_ADDRESS },
  });
  const activeContrib = useReadContract({
    address: addresses.contributionLedger,
    abi: contributionLedgerAbi,
    functionName: "activeContribution",
    args: address ? [address] : undefined,
    query: { enabled: enabled && addresses.contributionLedger !== ZERO_ADDRESS },
  });
  const isBuilder = useReadContract({
    address: addresses.contributorRegistry,
    abi: contributorRegistryAbi,
    functionName: "hasRole",
    args: address ? [address, ROLE.BUILDER] : undefined,
    query: { enabled: enabled && addresses.contributorRegistry !== ZERO_ADDRESS },
  });
  const pendingPoints = useReadContract({
    address: addresses.developerPool,
    abi: developerPoolAbi,
    functionName: "pendingPoints",
    args: address ? [address] : undefined,
    query: { enabled: enabled && addresses.developerPool !== ZERO_ADDRESS },
  });
  const bridgeCore = useReadContract({
    address: addresses.feeBridge,
    abi: feeBridgeAbi,
    functionName: "core",
    query: { enabled: addresses.feeBridge !== ZERO_ADDRESS },
  });
  const quoteBps = useReadContract({
    address: addresses.feeBridge,
    abi: feeBridgeAbi,
    functionName: "quoteFeeBps",
    args: address ? [address] : undefined,
    query: { enabled: enabled && addresses.feeBridge !== ZERO_ADDRESS },
  });
  const gmvSelf = useReadContract({
    address: addresses.settlementMirror,
    abi: settlementMirrorAbi,
    functionName: "lifetimeDeveloperGmv",
    args: address ? [address] : undefined,
    query: { enabled: enabled && addresses.settlementMirror !== ZERO_ADDRESS },
  });

  const scenarioHint =
    typeof window !== "undefined" ? new URLSearchParams(window.location.search).get("scenario") : null;

  const onClaim = () => {
    writeContract({
      address: addresses.stakerPool,
      abi: stakerPoolAbi,
      functionName: "claim",
    });
  };

  return (
    <div className="karma-economy karma-miniapp-shell">
      <div className="karma-brand">KARMA</div>
      <h1>Economy</h1>
      <p>
        经济面：质押档位、贡献权重与分红。交易验证与结算在主网络完成；本页只读/领奖。
        {tgUser?.username ? ` TG @${tgUser.username}` : tgUser?.id ? ` TG #${tgUser.id}` : ""}
        {tg ? " · WebApp" : ""}
      </p>
      {scenarioHint && (
        <p className="karma-hint" style={{ color: "var(--karma-accent)" }}>
          场景标记：{scenarioHint}
        </p>
      )}

      <div className="karma-row" style={{ justifyContent: "space-between", marginBottom: "1rem" }}>
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

      <div className="karma-row" style={{ marginBottom: "0.5rem" }}>
        {(
          [
            ["status", "状态"],
            ["wallet", "钱包"],
            ["rewards", "收益"],
            ["contrib", "贡献"],
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
      </div>

      {tab === "status" && (
        <section className="karma-panel">
          <h2>网络经济状态</h2>
          <div className="karma-meta">
            <div>
              <span>盈利模式</span>
              <strong>{revenueOn ? "ON" : "OFF · 冷启动"}</strong>
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
              <span>当前报价</span>
              <strong>{quoteBps.data != null ? `${quoteBps.data.toString()} bps` : "—"}</strong>
            </div>
            <div>
              <span>你的 lifetime GMV</span>
              <strong>{gmvSelf.data != null ? formatUnits(gmvSelf.data, 6) : "0"} USDC</strong>
            </div>
            <div>
              <span>FeeBridge.core</span>
              <strong style={{ fontSize: "0.8rem", wordBreak: "break-all" }}>
                {bridgeCore.data ?? "—"}
              </strong>
            </div>
            <div>
              <span>Bilateral</span>
              <strong style={{ fontSize: "0.8rem", wordBreak: "break-all" }}>
                {addresses.karmaBilateral !== ZERO_ADDRESS ? addresses.karmaBilateral : "—"}
              </strong>
            </div>
          </div>
          <p className="karma-hint" style={{ color: "var(--karma-muted)" }}>
            Verification / Evidence 不在本页。主仓校验通过后 settle → FeeBridge 才会更新 GMV。
            自成交（buyer==seller）不计 developer GMV。
          </p>
        </section>
      )}

      {tab === "wallet" && (
        <section className="karma-panel">
          <h2>钱包档位</h2>
          <div className="karma-meta">
            <div>
              <span>质押档</span>
              <strong>{TIER_LABEL[Number(tier.data ?? 0)] ?? "—"}</strong>
            </div>
            <div>
              <span>已质押</span>
              <strong>{stakeOf.data != null ? formatEther(stakeOf.data) : "0"} KARMA</strong>
            </div>
            <div>
              <span>你的费率</span>
              <strong>{revenueOn ? `${feeFor.data?.toString() ?? "—"} bps` : "0（冷启动）"}</strong>
            </div>
            <div>
              <span>BUILDER</span>
              <strong>{isBuilder.data ? "是" : "否 / 未注册"}</strong>
            </div>
          </div>
        </section>
      )}

      {tab === "rewards" && (
        <section className="karma-panel">
          <h2>收益</h2>
          <div className="karma-meta">
            <div>
              <span>质押分红 earned</span>
              <strong>{earned.data != null ? formatUnits(earned.data, 6) : "0"} USDC</strong>
            </div>
            <div>
              <span>开发者 pending</span>
              <strong>{pendingPoints.data != null ? pendingPoints.data.toString() : "0"} pts</strong>
            </div>
          </div>
          <button
            className={`karma-btn ${revenueOn ? "karma-btn-primary" : "karma-btn-locked"}`}
            type="button"
            disabled={!revenueOn || claiming || !earned.data}
            onClick={onClaim}
          >
            {revenueOn ? "领取质押分红" : "盈利未开启 · 分红锁定"}
          </button>
        </section>
      )}

      {tab === "contrib" && (
        <section className="karma-panel">
          <h2>贡献</h2>
          <div className="karma-meta">
            <div>
              <span>NFT weight</span>
              <strong>{nftWeight.data?.toString() ?? "0"}</strong>
            </div>
            <div>
              <span>活跃贡献分</span>
              <strong>{activeContrib.data?.toString() ?? "0"}</strong>
            </div>
            <div>
              <span>待 mint</span>
              <strong>{pendingMint.data?.toString() ?? "0"}</strong>
            </div>
          </div>
          <p>达阈值后的 mint / 审核在共建账本与主仓流程完成；此处只展示链上结果。</p>
        </section>
      )}
    </div>
  );
}
