# 合约地址对接说明

## 仓库边界

| 方向 | 允许操作 | 禁止操作 |
|------|----------|----------|
| karma-core → karma-economy | 经 `FeeBridge.collectAndRecord` 转入 USDC 手续费并镜像账单 | 写入任何其他 economy 状态 |
| karma-economy → karma-core | 调用 `IKarmaCoreView` 只读视图（部署为 `SettlementMirror`） | 修改核心结算状态（除可选 escrow 回调） |

## 推荐联动拓扑

```text
AtoB101/Karma KarmaBilateral
        │ settle → quoteFee / collectAndRecord
        ▼
   FeeBridge ──notifyFee──► Treasury
        │
        └──recordBill──► SettlementMirror (IKarmaCoreView)
                              ▲
          DeveloperRewardPool ┘
          DisputeArbitrator ──► CoreEscrowAdapter ──► (optional) core escrow target
```

## karma-core 侧最小改动

详见 [`integrations/karma-core/PATCH.md`](../integrations/karma-core/PATCH.md) 与可应用 diff：

`integrations/karma-core/patches/0001-add-treasury-feebridge.diff`

```bash
# 在 AtoB101/Karma 仓库
git apply --check path/to/karma8/integrations/karma-core/patches/0001-add-treasury-feebridge.diff
git apply path/to/karma8/integrations/karma-core/patches/0001-add-treasury-feebridge.diff
```

接线：

```solidity
Bilateral.setTreasury(treasury);
Bilateral.setFeeBridge(feeBridge);
// FeeBridge.core 必须是 Bilateral（DeployEconomy / WireKarmaCore 已设置）
```

结算时 Bilateral 会：

1. `quoteFee(developer, amount)` — `enableRevenueMode=false` 时为 0  
2. `collectAndRecord(...)` — 手续费转入 Treasury，GMV 写入 SettlementMirror  

本地可用 `ReferenceSettlementCore` + `BilateralFeeHook` 代替真实 Bilateral（`CoreLinkage` / `FlywheelE2E`）。

## karma-economy 只读接口

`IKarmaCoreView`（由 `SettlementMirror` 实现）：

- `getBillSnapshot(orderId)`
- `getDeveloperGmv(developer, fromTs, toTs)`
- `getTotalGmv(fromTs, toTs)`
- `isOrderFrozen(orderId)`

`DisputeArbitrator` 可通过 `CoreEscrowAdapter` 回调 `freezeOrder` / `releaseToSeller` / `refundToBuyer`；适配器会更新 mirror，并可选转发到 `ICoreEscrowTarget`。

## 部署与重接线

1. `forge script script/DeployEconomy.s.sol` — 部署经济栈 + FeeBridge/Mirror/Escrow，`FeeBridge.setCore(KARMA_CORE_ADDRESS)`  
2. 在 Karma 应用补丁后：`Bilateral.setTreasury` + `setFeeBridge`  
3. 如需重配：`forge script script/WireKarmaCore.s.sol`

验收：

```bash
forge test --match-contract CoreLinkage -vv
forge test --match-contract FlywheelE2E -vv
forge test --match-contract GoLiveAcceptance -vv
bash integrations/karma-core/verify_patch.sh
```

## 不可变参数（链上常量）

```
FEE_BPS = 20                    // 0.2%
DEVELOPER_POOL_PCT = 40
STAKER_POOL_PCT = 30
VERIFIER_POOL_PCT = 20
BUYBURN_POOL_PCT = 10
KARMA_TOTAL_SUPPLY = 1e9 ether  // 零增发
```

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
| SettlementMirror | |
| FeeBridge | |
| CoreEscrowAdapter | |
| karma-core (Bilateral) | |
| USDC | |
