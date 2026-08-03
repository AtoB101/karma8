import { useState } from "react";
import { useAccount, useReadContract, useWriteContract } from "wagmi";
import { EconomyAddresses, governorAbi } from "../lib/abis";
import { useRevenueMode } from "../hooks/useRevenueMode";
import "../styles/economy.css";

type Props = { addresses: EconomyAddresses };

export function GovernancePage({ addresses }: Props) {
  const { address } = useAccount();
  const { enabled: revenueOn } = useRevenueMode(addresses.treasury);
  const [description, setDescription] = useState("Enable KARMA revenue flywheel");
  const [proposalId, setProposalId] = useState("1");
  const { writeContract, isPending } = useWriteContract();

  const state = useReadContract({
    address: addresses.governor,
    abi: governorAbi,
    functionName: "state",
    args: [BigInt(proposalId || "0")],
    query: { enabled: Boolean(proposalId) },
  });

  const proposeEnable = (enable: boolean) => {
    writeContract({
      address: addresses.governor,
      abi: governorAbi,
      functionName: "proposeEnableRevenue",
      args: [enable, description],
    });
  };

  const vote = (support: boolean) => {
    writeContract({
      address: addresses.governor,
      abi: governorAbi,
      functionName: "vote",
      args: [BigInt(proposalId || "0"), support],
    });
  };

  const execute = () => {
    writeContract({
      address: addresses.governor,
      abi: governorAbi,
      functionName: "execute",
      args: [BigInt(proposalId || "0")],
    });
  };

  return (
    <section className="karma-economy">
      <div className="karma-brand">KARMA</div>
      <h1>治理提案</h1>
      <p>
        投票权重 = 质押数量 × 时长系数。可治理国库补贴、节点惩罚细则与生态活动；
        <strong>不可</strong>修改 0.2% 手续费与 40/30/20/10 分账。
      </p>

      <div className="karma-meta">
        <div>
          <span>盈利模式</span>
          <strong>{revenueOn ? "已开启" : "关闭（测试/冷启动）"}</strong>
        </div>
        <div>
          <span>投票周期</span>
          <strong>7 天</strong>
        </div>
        <div>
          <span>通过阈值</span>
          <strong>≥ 51%</strong>
        </div>
      </div>

      <div className="karma-panel">
        <h2>发起提案</h2>
        <div className="karma-row">
          <input
            className="karma-input"
            style={{ minWidth: "20rem", flex: 1 }}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="提案说明"
          />
          <button
            className="karma-btn karma-btn-primary"
            disabled={!address || isPending}
            onClick={() => proposeEnable(true)}
          >
            提案开启盈利
          </button>
          <button
            className="karma-btn karma-btn-ghost"
            disabled={!address || isPending}
            onClick={() => proposeEnable(false)}
          >
            提案关闭盈利
          </button>
        </div>
      </div>

      <div className="karma-panel">
        <h2>投票 / 执行</h2>
        <div className="karma-row">
          <input
            className="karma-input"
            value={proposalId}
            onChange={(e) => setProposalId(e.target.value)}
            placeholder="提案 ID"
          />
          <button className="karma-btn karma-btn-primary" disabled={!address || isPending} onClick={() => vote(true)}>
            赞成
          </button>
          <button className="karma-btn karma-btn-ghost" disabled={!address || isPending} onClick={() => vote(false)}>
            反对
          </button>
          <button className="karma-btn karma-btn-ghost" disabled={!address || isPending} onClick={execute}>
            执行
          </button>
        </div>
        {state.data && (
          <div className="karma-meta">
            <div>
              <span>进行中</span>
              <strong>{state.data[0] ? "是" : "否"}</strong>
            </div>
            <div>
              <span>已达阈值</span>
              <strong>{state.data[1] ? "是" : "否"}</strong>
            </div>
            <div>
              <span>赞成</span>
              <strong>{state.data[3].toString()}</strong>
            </div>
            <div>
              <span>反对</span>
              <strong>{state.data[4].toString()}</strong>
            </div>
          </div>
        )}
      </div>
    </section>
  );
}