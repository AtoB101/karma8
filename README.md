# karma-economy

KARMA 经济生态独立仓库（配套 `karma-core` A2A 智能体托管结算系统）。

两个仓库代码隔离，链上仅通过合约地址交互，实现风险解耦。

## 核心原则

- **不可篡改**：手续费 `0.2%`（20 bps）与国库分账 `40/30/20/10` 部署后永久锁定（常量，无 setter）。
- **分阶段上线**：`Treasury.enableRevenueMode` 默认 `false`；测试网关闭扣费/分红/回购，仅做逻辑验证。
- **安全隔离**：
  - `karma-core` → `karma-economy`：仅允许向 `Treasury` 转入 USDC。
  - `karma-economy` → `karma-core`：仅允许读取账单快照与 GMV 视图（`IKarmaCoreView`）。

## 合约清单

| 合约 | 路径 | 说明 |
|------|------|------|
| `KarmaToken` | `src/token/KarmaToken.sol` | 10 亿总量，零增发 |
| `KarmaVesting` | `src/token/KarmaVesting.sol` | 分配解锁规则 |
| `MultiSigWallet` | `src/governance/MultiSigWallet.sol` | 7 人多签（资金 ≥5/7，控制器 7/7） |
| `KarmaGovernor` | `src/governance/KarmaGovernor.sol` | 质押权重治理，禁改费率 |
| `MultiTierStake` | `src/staking/MultiTierStake.sol` | 四层质押 |
| `ContributionNFT` | `src/nft/ContributionNFT.sol` | 灵魂绑定贡献凭证 |
| `Treasury` | `src/treasury/Treasury.sol` | 国库 + Chainlink Automation 周分账 |
| `DeveloperRewardPool` | `src/pools/DeveloperRewardPool.sol` | 40% 开发者池 |
| `StakerRewardPool` | `src/pools/StakerRewardPool.sol` | 30% 质押分红池 |
| `VerifierNodePool` | `src/pools/VerifierNodePool.sol` | 20% 仲裁节点池 |
| `AutoBuyBurn` | `src/pools/AutoBuyBurn.sol` | 10% 回购销毁（默认暂停兑换） |
| `DisputeArbitrator` | `src/arbitration/DisputeArbitrator.sol` | 15 节点随机仲裁 |

## 快速开始

```bash
# 安装 Foundry: https://book.getfoundry.sh/getting-started/installation
forge install
forge build
forge test
```

## 部署

参见 [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) 与 [docs/SWITCH_OPS.md](docs/SWITCH_OPS.md)。

```bash
cp .env.example .env
# 填入 USDC / karma-core / 多签成员地址
forge script script/DeployEconomy.s.sol:DeployEconomy --rpc-url $RPC_URL --broadcast
```

## 前端组件

`frontend/` 提供可嵌入的 React 页面组件：质押、节点注册、治理提案、贡献 NFT 申领。盈利未开启时分红/手续费减免按钮置灰。

## 文档

- [部署文档](docs/DEPLOYMENT.md)
- [合约地址对接说明](docs/INTEGRATION.md)
- [开关启停操作手册](docs/SWITCH_OPS.md)
