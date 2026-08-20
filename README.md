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

## 与 karma-core 对接

本仓库提供经济侧桥接（`DeployEconomy` 已默认部署并接线）：

- `FeeBridge`：唯一收费写入路径（USDC → Treasury + GMV 镜像）
- `SettlementMirror`：账单/GMV 只读视图（`IKarmaCoreView`）
- `CoreEscrowAdapter`：仲裁冻结/放款回调（可选转发到 core escrow）
- `ReferenceSettlementCore`：本地联调用的结算替身
- 生产补丁（unified diff）：[`integrations/karma-core/patches/0001-add-treasury-feebridge.diff`](integrations/karma-core/patches/0001-add-treasury-feebridge.diff)
- 接线脚本：`script/WireKarmaCore.s.sol`

本地飞轮 / 95% 上线验收：

```bash
forge test --match-contract CoreLinkage -vv
forge test --match-contract FlywheelE2E -vv
make golive   # GoLiveAcceptance + SecurityHardening + karma-core patch verify
```

详见 [`docs/GO_LIVE_95.md`](docs/GO_LIVE_95.md)。

本地 demo 部署：

```bash
# terminal 1
make demo-anvil
# terminal 2
make demo-deploy   # writes deployments/local.json
```

## 前端

`frontend/` 可嵌入组件 + Vite demo 控制台（质押 / 节点 / 治理 / 贡献 NFT）。  
盈利未开启时分红与手续费减免按钮置灰。

```bash
cd frontend && npm i && npm run dev
```

## 文档

- [商业落地清单](docs/COMMERCIAL_READINESS.md)
- [部署文档](docs/DEPLOYMENT.md)
- [合约地址对接说明](docs/INTEGRATION.md)
- [共建计分规格 v1](docs/cocreation/COCREATION_SCORE_V1.md)
- [开关启停操作手册](docs/SWITCH_OPS.md)
- [安全红线](docs/SECURITY.md)
