# 将 treasury/feeBridge 合入 AtoB101/Karma

> **状态（2026-08）**：`AtoB101/Karma` 已通过 PR #141 合入 `feeBridge` / `_collectEconomyFee`。  
> `bash integrations/karma-core/verify_patch.sh` 对已合入 upstream 会报告 `PASS (upstream integrated)`。  
> 跨仓实锤：`bash integrations/karma-core/run_cross_repo_test.sh`。

## 方式 A：应用 diff（历史 / 分叉回放）

```bash
git clone https://github.com/AtoB101/Karma.git
cd Karma
git apply --check path/to/karma8/integrations/karma-core/patches/0001-add-treasury-feebridge.diff
git apply path/to/karma8/integrations/karma-core/patches/0001-add-treasury-feebridge.diff
forge test --match-contract KarmaBilateral -vv
```

也可用 Cursor/人工按 `PATCH.md` 手工改 `_executeSettle`。

校验补丁包（在 karma8 仓库）：

```bash
bash integrations/karma-core/verify_patch.sh
```

该脚本会拉取最新 upstream、`git apply --check`，并确认 `_collectEconomyFee` / `feeBridge` 注入成功。

## 方式 B：依赖 karma8 库（长期）

在 Karma `foundry.toml`：

```toml
libs = ["lib"]
```

```bash
forge install AtoB101/karma8
```

然后在 Bilateral 中调用 `BilateralFeeHook.collectOnSettle(...)`（见 `src/integration/BilateralFeeHook.sol`）。

## 接线清单

1. 部署 karma-economy（`DeployEconomy` — 已包含 FeeBridge / SettlementMirror / CoreEscrowAdapter）
2. 确认 `FeeBridge.core == KarmaBilateral`（部署时由 `KARMA_CORE_ADDRESS` 写入；可重跑 `WireKarmaCore`）
3. 确认 `SettlementMirror.isReporter(FeeBridge) == true`
4. `KarmaBilateral.setTreasury(Treasury)`
5. `KarmaBilateral.setFeeBridge(FeeBridge)`
6. 冷启动验证：`enableRevenueMode=false` → settle 手续费为 0，GMV 有镜像
7. 治理开启后再验证 0.2%/0.1%/0 费率

## 验收命令（economy 侧）

```bash
forge test --match-contract CoreLinkage -vv
forge test --match-contract FlywheelE2E -vv
forge test --match-contract GoLiveAcceptance -vv
bash integrations/karma-core/verify_patch.sh
```
