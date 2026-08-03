# karma-economy 部署文档

## 前置条件

1. Foundry 已安装（`forge` / `cast` / `anvil`）
2. 已部署或已知地址：
   - USDC（测试网可用 Mock）
   - `karma-core` 只读视图地址（实现 `IKarmaCoreView`）
   - Uniswap V2 Router（可选；测试网回购默认暂停）
3. 准备 7 个多签成员地址（创始人 2 / 生态开发者 2 / 仲裁代表 2 / 社区 1）

## 环境变量

复制 `.env.example`：

```bash
USDC_ADDRESS=
KARMA_CORE_ADDRESS=
UNISWAP_ROUTER=0x0000000000000000000000000000000000000000
MSIG_OWNER_0=
MSIG_OWNER_1=
MSIG_OWNER_2=
MSIG_OWNER_3=
MSIG_OWNER_4=
MSIG_OWNER_5=
MSIG_OWNER_6=
PRIVATE_KEY=
RPC_URL=
```

## 部署步骤

### 1. 部署经济栈

```bash
forge script script/DeployEconomy.s.sol:DeployEconomy \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

记录输出地址：`MultiSig` / `KARMA` / `Stake` / `Treasury` / 各 Pool / `Governor` / `Arbitrator`。

### 2. 多签初始化（7/7 Controller）

通过 `MultiSigWallet` 提交并确认以下调用（`OpKind.Controller` = 7/7）：

1. `Treasury.setGovernance(governor)`
2. `MultiTierStake.setGovernance(governor)`
3. `MultiTierStake.setArbitrator(arbitrator)`
4. `DisputeArbitrator.setNodePool(verifierPool)`
5. `VerifierNodePool` 侧仲裁地址若未设置，由部署者在移交 treasury 前完成
6. `KarmaVesting.setStake(stake)`，并向 vesting 转入对应分配额度后 `createGrant(...)`

### 3. karma-core 对接

在 `karma-core` 仅新增国库地址变量，指向本仓库 `Treasury`：

- 结算收取手续费时：`USDC.approve(treasury, fee)` + `Treasury.notifyFee(fee)`
- **禁止** 为 karma-core 增加 Owner/管理员权限

### 4. Chainlink Automation

注册 Automation Upkeep，Target = `Treasury`：

- `checkUpkeep` / `performUpkeep` 已实现
- 建议间隔：7 天（合约内部也强制 `WEEKLY_DISTRIBUTION_INTERVAL`）
- 当 `enableRevenueMode=false` 时 upkeep 不会执行分账

### 5. 测试网验收清单

- [ ] `Treasury.enableRevenueMode() == false`
- [ ] `AutoBuyBurn.swapPaused() == true`
- [ ] 手动（仅在受控环境）开启 revenue → 注入 USDC → `performUpkeep` → 校验 40/30/20/10
- [ ] 验证后 **再次关闭** revenue mode，回归免费模式
- [ ] 确认无法调用任意私人转账（`Treasury.transfer` 永久 revert）

## 主网时序

1. **冷启动**：部署待命经济栈，revenue=false，积累 GMV
2. **治理开启**：社区提案 `EnableRevenueMode`
3. **飞轮启动**：扣费 / 分红 / 回购 / 手续费减免生效
4. **自动化**：Chainlink 周分账无人值守
