import { useState } from "react";
import { parseEther } from "viem";
import { useAccount, useReadContract, useWriteContract } from "wagmi";
import { EconomyAddresses, TIER, stakeAbi } from "../lib/abis";
import "../styles/economy.css";

type Props = { addresses: EconomyAddresses };

/** 仲裁节点注册：质押 ≥500,000 KARMA 并选择 Verifier 层级。 */
export function NodeRegisterPage({ addresses }: Props) {
  const { address } = useAccount();
  const [amount, setAmount] = useState("500000");
  const { writeContract, isPending } = useWriteContract();

  const active = useReadContract({
    address: addresses.stake,
    abi: stakeAbi,
    functionName: "isActiveVerifier",
    args: address ? [address] : undefined,
    query: { enabled: Boolean(address) },
  });

  const onRegister = () => {
    writeContract({
      address: addresses.stake,
      abi: stakeAbi,
      functionName: "stake",
      args: [parseEther(amount || "0"), TIER.Verifier],
    });
  };

  return (
    <section className="karma-economy">
      <div className="karma-brand">KARMA</div>
      <h1>节点注册</h1>
      <p>质押至少 500,000 KARMA 并锁仓 ≥12 个月，获得纠纷仲裁资格与节点奖励池份额。</p>

      <div className="karma-meta">
        <div>
          <span>节点状态</span>
          <strong>{active.data ? "已激活仲裁节点" : "未激活"}</strong>
        </div>
        <div>
          <span>最低质押</span>
          <strong>500,000 KARMA</strong>
        </div>
        <div>
          <span>锁仓</span>
          <strong>≥ 12 个月</strong>
        </div>
      </div>

      <div className="karma-panel">
        <h2>注册 / 增资</h2>
        <div className="karma-row">
          <input
            className="karma-input"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="质押数量"
          />
          <button className="karma-btn karma-btn-primary" disabled={!address || isPending} onClick={onRegister}>
            注册节点
          </button>
        </div>
        <p>节点奖励领取在盈利模式开启后可用；注册与投票功能始终开放。</p>
      </div>
    </section>
  );
}