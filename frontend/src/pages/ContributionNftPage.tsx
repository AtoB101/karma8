import { useAccount, useReadContract } from "wagmi";
import { EconomyAddresses, contributionNftAbi } from "../lib/abis";
import { useRevenueMode } from "../hooks/useRevenueMode";
import "../styles/economy.css";

type Props = { addresses: EconomyAddresses };

/**
 * 贡献 NFT 申领页：铸造由多签审核链下触发；页面展示身份与权重。
 * 实测阶段仅作身份凭证；盈利开启后权重参与开发者池分红。
 */
export function ContributionNftPage({ addresses }: Props) {
  const { address } = useAccount();
  const { enabled: revenueOn } = useRevenueMode(addresses.treasury);

  const balance = useReadContract({
    address: addresses.contributionNft,
    abi: contributionNftAbi,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: Boolean(address) },
  });

  const weight = useReadContract({
    address: addresses.contributionNft,
    abi: contributionNftAbi,
    functionName: "totalWeightOf",
    args: address ? [address] : undefined,
    query: { enabled: Boolean(address) },
  });

  return (
    <section className="karma-economy">
      <div className="karma-brand">KARMA</div>
      <h1>贡献 NFT</h1>
      <p>灵魂绑定、不可转让。经多签审核 SDK / MCP 插件 / 工具贡献后铸造，携带固定权重。</p>

      <div className="karma-meta">
        <div>
          <span>持有数量</span>
          <strong>{balance.data?.toString() ?? "—"}</strong>
        </div>
        <div>
          <span>累计权重</span>
          <strong>{weight.data?.toString() ?? "—"}</strong>
        </div>
        <div>
          <span>分红用途</span>
          <strong>{revenueOn ? "已计入开发者池" : "身份凭证（分红锁定）"}</strong>
        </div>
      </div>

      <div className="karma-panel">
        <h2>申领流程</h2>
        <p>1. 提交贡献材料至社区多签审核通道。</p>
        <p>2. 7 人多签确认后由 `ContributionNFT.mint` 铸造至你的钱包。</p>
        <p>3. NFT 不可转让；盈利模式开启后权重自动参与开发者分红结算。</p>
        <div className="karma-row">
          <button className="karma-btn karma-btn-locked" disabled>
            等待多签铸造
          </button>
          <button className={`karma-btn ${revenueOn ? "karma-btn-ghost" : "karma-btn-locked"}`} disabled={!revenueOn}>
            {revenueOn ? "权重已生效" : "分红权重 · 已锁定"}
          </button>
        </div>
      </div>
    </section>
  );
}