# 开关启停操作手册

## 全局开关

| 开关 | 合约 | 默认 | 作用 |
|------|------|------|------|
| `enableRevenueMode` | `Treasury` | `false` | 总开关：分账、分红 notify、补贴 |
| `revenueMode` | 各 RewardPool / AutoBuyBurn / MultiTierStake | `false` | 由 Treasury/Governor 联动 |
| `swapPaused` | `AutoBuyBurn` | `true` | 暂停 USDC→KARMA 兑换销毁 |

## 测试网规则（强制）

1. 部署后确认 `enableRevenueMode == false`
2. 确认 `AutoBuyBurn.swapPaused == true`
3. 可进行**受控模拟**：短暂开启 → 验证分账/分红/回购逻辑 → **必须再次关闭**
4. 严禁测试网长期开启真实扣费与分红

## 开启盈利模式（主网阶段 2）

### 路径 A：治理提案（推荐）

1. 持有质押投票权的地址调用：
   ```text
   KarmaGovernor.proposeEnableRevenue(true, "Enable KARMA revenue flywheel")
   ```
2. 7 天投票期，赞成票 ≥ 51% 总投票权重
3. 任何人调用 `KarmaGovernor.execute(id)`
4. 自动执行：
   - `Treasury.setEnableRevenueMode(true)`
   - 向各 Pool 传播 `setRevenueMode(true)`
   - `MultiTierStake.setRevenueMode(true)`（手续费减免生效）

### 路径 B：应急关闭

```text
KarmaGovernor.proposeEnableRevenue(false, "Emergency disable revenue")
```

投票通过后执行，立即停止分账与分红领取。

## 回购销毁

测试网保持：

```text
AutoBuyBurn.swapPaused = true
```

主网飞轮启动后，由 Treasury 控制器（≥5/7 多签）调用：

```text
AutoBuyBurn.setSwapPaused(false)
```

然后再执行 `executeBuyBurn(amountIn, amountOutMin)` 或由运维 bot 调用。

## 手动分账（调试）

仅当 `enableRevenueMode=true`：

```text
Treasury.distributeNow()   // onlyController (≥5/7 via multisig)
Treasury.performUpkeep("") // Chainlink / 任何人可触发（时间窗满足时）
```

## 治理禁区

以下操作被协议拒绝 / 不存在 setter：

- 修改 `0.2%` 手续费
- 修改 `40/30/20/10` 分账比例
- `Treasury` 直接转账到私人地址

`KarmaGovernor.proposeCustomCall` 会拦截 `setFeeBps` / `setSplitRatios` 选择器。

## 故障隔离

若经济模块出现漏洞：

1. 立即治理关闭 `enableRevenueMode`
2. `karma-core` 将 `treasury` 置空或停止 `notifyFee`（core 侧运维）
3. 核心结算继续运行，不受 economy 停机影响
