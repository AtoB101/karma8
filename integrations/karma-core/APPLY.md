# 将 treasury/feeBridge 合入 AtoB101/Karma

> 当前 CI identity **没有** 对 `AtoB101/Karma` 的 push/fork 权限，因此补丁以可应用产物形式交付。  
> 仓库维护者在 Karma 侧执行以下步骤即可完成跨仓库 95% 门禁中的核心缺口。

## 方式 A：应用 diff（推荐）

```bash
git clone https://github.com/AtoB101/Karma.git
cd Karma
# 从 karma8 拷贝补丁
git apply --check path/to/karma8/integrations/karma-core/patches/0001-add-treasury-feebridge.diff
git apply path/to/karma8/integrations/karma-core/patches/0001-add-treasury-feebridge.diff
forge test
```

也可用 Cursor/人工按 `PATCH.md` 手工改 `_executeSettle`。

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

1. 部署 karma-economy（`DeployEconomy` / `DeployLocalDemo`）
2. `FeeBridge.setCore(KarmaBilateral)`
3. `SettlementMirror.setReporter(FeeBridge, true)`
4. `KarmaBilateral.setTreasury(Treasury)`
5. `KarmaBilateral.setFeeBridge(FeeBridge)`
6. 冷启动验证：`enableRevenueMode=false` → settle 手续费为 0，GMV 有镜像
7. 治理开启后再验证 0.2%/0.1%/0 费率

## 验收命令（economy 侧）

```bash
forge test --match-contract FlywheelE2E -vv
forge test --match-contract GoLiveAcceptance -vv
bash integrations/karma-core/verify_patch.sh
```
