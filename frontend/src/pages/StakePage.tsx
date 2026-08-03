import { useState } from "react";
import { parseEther, formatEther } from "viem";
import { useAccount, useReadContract, useWriteContract } from "wagmi";
import { EconomyAddresses, TIER, stakeAbi, stakerPoolAbi } from "../lib/abis";
import { useRevenueMode } from "../hooks/useRevenueMode";
import "../styles/economy.css";

const TIER_OPTIONS = [
  { value: TIER.Public, label: "大众活期" },
  { value: TIER.Developer, label: "开发者资质 (≥100k)" },
  { value: TIER.Verifier, label: "仲裁节点 (≥500k)" },
  { value: TIER.Partner, label: "生态合伙人 (≥5M)" },
] as const;

type Props = { addresses: EconomyAddresses };

export function StakePage({ addresses }: Props) {
  const { address } = useAccount();
  const { enabled: revenueOn } = useRevenueMode(addresses.treasury);
  const [amount, setAmount] = useState("1000");
  const [tier, setTier] = useState<number>(TIER.Public);
  const { writeContract, isPending } = useWriteContract();

  const stakeOf = useReadContract({
    address: addresses.stake,
    abi: stakeAbi,
    functionName: "stakeOf",
    args: address ? [address] : undefined,
    query: { enabled: Boolean(address) },
  });

  const weight = useReadContract({
    address: addresses.stake,
    abi: stakeAbi,
    functionName: "votingWeight",
    args: address ? [address] : undefined,
    query: { enabled: Boolean(address) },
  });

  const feeBps = useReadContract({
    address: addresses.stake,
    abi: stakeAbi,
    functionName: "feeBpsFor",
    args: address ? [address] : undefined,
    query: { enabled: Boolean(address) },
  });

  const earned = useReadContract({
    address: addresses.stakerPool,
    abi: stakerPoolAbi,
    functionName: "earned",
    args: address ? [address] : undefined,
    query: { enabled: Boolean(address) },
  });

  const onStake = () => {
    writeContract({
      address: addresses.stake,
      abi: stakeAbi,
      functionName: "stake",
      args: [parseEther(amount || "0"), tier],
    });
  };

  const onClaim = () => {
    writeContract({
      address: addresses.stakerPool,
      abi: stakerPoolAbi,
      functionName: "claim",
    });
  };

  return (
    <section className="karma-economy">
      <div className="karma-brand">KARMA</div>
      <h1>质押</h1>
      <p>四层质押决定治理权重、开发者权益与节点资格。盈利模式未开启前，USDC 分红与手续费减免保持锁定。</p>

      <div className="karma-meta">
        <div>
          <span>已质押</span>
          <strong>{stakeOf.data ? formatEther(stakeOf.data) : "—"} KARMA</strong>
        </div>
        <div>
          <span>投票权重</span>
          <strong>{weight.data ? formatEther(weight.data) : "—"}</strong>
        </div>
        <div>
          <span>有效费率</span>
          <strong>{revenueOn ? `${feeBps.data ?? "—"} bps` : "免费模式"}</strong>
        </div>
        <div>
          <span>待领分红</span>
          <strong>{earned.data ? `${earned.data.toString()} USDC` : "—"}</strong>
        </div>
      </div>

      <div className="karma-panel">
        <h2>质押 KARMA</h2>
        <div className="karma-row">
          <input
            className="karma-input"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="数量"
          />
          <select className="karma-select" value={tier} onChange={(e) => setTier(Number(e.target.value))}>
            {TIER_OPTIONS.map((t) => (
              <option key={t.value} value={t.value}>
                {t.label}
              </option>
            ))}
          </select>
          <button className="karma-btn karma-btn-primary" disabled={!address || isPending} onClick={onStake}>
            质押
          </button>
        </div>
      </div>

      <div className="karma-panel">
        <h2>领取质押分红</h2>
        <div className="karma-row">
          <button
            className={`karma-btn ${revenueOn ? "karma-btn-primary" : "karma-btn-locked"}`}
            disabled={!revenueOn || !address || isPending}
            onClick={onClaim}
          >
            {revenueOn ? "领取 USDC" : "盈利未开启 · 已锁定"}
          </button>
          {!revenueOn && <p className="karma-hint">Treasury.enableRevenueMode = false</p>}
        </div>
      </div>
    </section>
  );
}