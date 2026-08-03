# 合约地址对接说明

## 仓库边界

| 方向 | 允许操作 | 禁止操作 |
|------|----------|----------|
| karma-core → karma-economy | 向 `Treasury` 转入 USDC 手续费 | 写入任何 economy 状态（除转账/notifyFee） |
| karma-economy → karma-core | 调用 `IKarmaCoreView` 只读视图 | 修改核心结算状态 |

## karma-core 侧最小改动

仅新增：

```solidity
address public treasury; // karma-economy Treasury
```

结算伪代码：

```solidity
uint256 fee = amount * 20 / 10_000; // 或通过 stake.feeBpsFor(developer) 读取动态费率
IERC20(usdc).approve(treasury, fee);
ITreasury(treasury).notifyFee(fee);
```

> 测试网 / 冷启动阶段：`feeBpsFor` 在 `revenueMode=false` 时返回 `0`，应保持免费接入。

## karma-economy 只读接口

`IKarmaCoreView`（`src/interfaces/IKarmaCoreView.sol`）：

- `getBillSnapshot(orderId)`
- `getDeveloperGmv(developer, fromTs, toTs)`
- `getTotalGmv(fromTs, toTs)`
- `isOrderFrozen(orderId)`

`DisputeArbitrator` 可通过可选 `coreEscrowAdapter` 回调 `freezeOrder` / `releaseToSeller` / `refundToBuyer`；该适配器属于 karma-core 外围模块，非本仓库强制依赖。

## 不可变参数（链上常量）

```
FEE_BPS = 20                    // 0.2%
DEVELOPER_POOL_PCT = 40
STAKER_POOL_PCT = 30
VERIFIER_POOL_PCT = 20
BUYBURN_POOL_PCT = 10
KARMA_TOTAL_SUPPLY = 1e9 ether  // 零增发
```

读取方式：

- `Treasury.feeBps()`
- `Treasury.splitRatios()`

## 前端只读数据源

| 页面 | 主要调用 |
|------|----------|
| 质押 | `MultiTierStake.positions` / `votingWeight` / `feeBpsFor` / `tierOf` |
| 节点注册 | `stake` with `Tier.Verifier`；`isActiveVerifier` |
| 治理 | `KarmaGovernor.proposals` / `state` / `vote` |
| 贡献 NFT | `ContributionNFT.totalWeightOf` / `tokenURI` |
| 分红领取 | 各 Pool `claimableOf` / `earned`；需先读 `Treasury.enableRevenueMode` |

## 地址登记表（部署后填写）

| 名称 | 地址 |
|------|------|
| MultiSigWallet | |
| KarmaToken | |
| MultiTierStake | |
| ContributionNFT | |
| KarmaVesting | |
| Treasury | |
| DeveloperRewardPool | |
| StakerRewardPool | |
| VerifierNodePool | |
| AutoBuyBurn | |
| DisputeArbitrator | |
| KarmaGovernor | |
| karma-core | |
| USDC | |
