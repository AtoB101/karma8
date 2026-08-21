# Karma 主仓 ↔ karma8 对齐与实现清单

> 给 `AtoB101/Karma` 维护者 / Cloud Agent 使用。  
> 经济仓：`AtoB101/karma8`  
> 日期：2026-08-21

---

## 一、仓库边界（必须遵守）

| 主仓 Karma 负责 | karma8 负责 | 禁止 |
|-----------------|-------------|------|
| Telegram Bot / MiniApp 壳 | FeeBridge / Treasury / 质押 / NFT | 主仓重做费率、国库分账 |
| initData 服务端验签、SIWE、Identity、Session | SettlementMirror GMV 镜像 | 主仓无限 USDC approve |
| Discovery / Quote / Order / Intent | Cocreation Registry / Ledger / Score | MiniApp 只信前端 tg user id |
| **Evidence + Verification + Risk + Dispute** | 经济面板 `?view=miniapp` | 经济仓实现 VerificationEngine |
| Bilateral lock / settle 编排 | Developer/Staker/Verifier 分红池 | |

```text
TG MiniApp → Karma API（主仓）→ Evidence → Verification PASS
                                      → Bilateral.settle
                                      → FeeBridge（karma8）
                                      → Treasury / Mirror / 分红
MiniApp Wallet Tab → 嵌入 karma8 /?view=miniapp
```

---

## 二、必须与 karma8 对齐的内容（接口 / 地址 / 行为）

### 2.1 链上结算对接（已合入主仓 feeBridge 补丁）

主仓 `KarmaBilateral` 必须：

1. 已有 `treasury` / `feeBridge` 状态与 `setTreasury` / `setFeeBridge`（PR #141 已合）
2. `_executeSettle` 调用 `FeeBridge.quoteFee` + `collectAndRecord`
3. 冷启动 `enableRevenueMode=false` 时 **fee=0 仍要 collectAndRecord**（记 GMV）
4. `orderId` = `bytes32(bindingId)`，与 Mirror 账单一致
5. `developer` 字段 = 适配器/BUILDER 归因地址（进 DeveloperRewardPool GMV）

接线顺序：

```text
1. 部署 Bilateral（或使用已有地址）
2. karma8 DeployEconomy：KARMA_CORE_ADDRESS=<Bilateral>
3. Bilateral.setTreasury(Treasury)
4. Bilateral.setFeeBridge(FeeBridge)
5. 确认 FeeBridge.core == Bilateral
```

参考：karma8 `integrations/karma-core/APPLY.md`、`docs/INTEGRATION.md`

### 2.2 主仓结算后只允许的经济写路径

| 允许 | 禁止 |
|------|------|
| `FeeBridge.collectAndRecord(...)` | 直接改 karma8 池内部账本 |
| （仲裁可选）读 SettlementMirror / 听 CoreEscrowAdapter 事件 | 主仓合约持有可改 FEE_BPS 的 setter |

### 2.3 地址与环境变量（主仓 BFF / MiniApp 配置）

从 karma8 `deployments/*.json` 或 DeployEconomy 日志读取：

```text
TREASURY
FEE_BRIDGE
SETTLEMENT_MIRROR
STAKE
GOVERNOR
STAKER_POOL
DEVELOPER_POOL
CONTRIBUTION_NFT
CONTRIBUTOR_REGISTRY
CONTRIBUTION_LEDGER
COCREATION_SCORE_VIEW
KARMA_TOKEN
USDC
KARMA_BILATERAL          # 主仓自己的结算合约
```

MiniApp 经济面嵌入：

```text
https://<economy-host>/?view=miniapp
https://<economy-host>/?view=miniapp&tab=rewards
```

说明：karma8 `integrations/telegram-miniapp/ECONOMY_SURFACE.md`

### 2.4 ABI 对齐（主仓前端 / BFF eth_call）

以 karma8 `frontend/src/lib/abis.ts` 为准，至少：

- `treasuryAbi`：`enableRevenueMode`, `feeBps`, `splitRatios`
- `feeBridgeAbi`：`core`, `quoteFeeBps`
- `stakeAbi`：`tierOf`, `stakeOf`, `feeBpsFor`
- `stakerPoolAbi` / `developerPoolAbi`：`earned`, `pendingPoints`, `claim`
- `contributionNftAbi` / `contributionLedgerAbi` / `contributorRegistryAbi`
- `cocreationScoreAbi`：`scoreBuilder`, `scoreExpert`

### 2.5 共建计分对齐（可选第二阶段）

karma8 已有链上：`ContributorRegistry` / `ContributionLedger` / `CocreationScoreView`。

主仓还需：

| 项 | 说明 |
|----|------|
| 链下 API | `register` / `events` / `accept` / `score` / `mint-request` |
| `R_settle` 回写 | settle 后 `CocreationScoreView.setSettleRep(wallet, score)` |
| high_risk | TEMPLATE_LIVE 且 Q>Accepted 需 SCENE_OWNER / OWNER_CONFIRM |
| 配置初值 | 复制 `docs/cocreation/cocreation_score.v1.yaml` |

详见：`integrations/karma-core/COCREATION_MAIN_PATCH.md`

### 2.6 行为约定

| 场景 | 期望 |
|------|------|
| revenueMode=false | settle 不扣费，Mirror 有 GMV；分红 claim 锁定 |
| revenueMode=true | 0.2%/0.1%/0 按质押档；国库 40/30/20/10 |
| buyer==seller | Mirror **不**计 developer GMV（反自成交） |
| Verification ≠ PASS | **不得** finalize settle / 不得打款 |

---

## 三、主仓必须实现的内容（完整业务）

产品规格原文：karma8 `docs/miniapp/Karma_Telegram_MiniApp_V1.0.txt`

### Sprint 1 — Identity
- [ ] Wallet Connect（目标链 + USDC）
- [ ] SIWE / EIP-4361 challenge + 验签
- [ ] 创建 `karma_identity`（wallet / business / agent / permission）
- [ ] Identity Dashboard

### Sprint 2 — Telegram
- [ ] Karma Bot + Mini App 壳
- [ ] **initData 服务端验签**（强制）
- [ ] Telegram ↔ karma_identity 绑定
- [ ] Session 签发 / 过期 / 防重放

### Sprint 3 — Registry
- [ ] Business Identity 认证
- [ ] Agent 注册（endpoint / capabilities）
- [ ] Capability / Offer 发布

### Sprint 4 — Discovery
- [ ] Chat Intent 抽取
- [ ] Capability 搜索 + Agent 排序（可加信誉 / 贡献分加权）

### Sprint 5 — Commerce
- [ ] Quote / Negotiation
- [ ] Intent Package + 双方签名
- [ ] Order / Bill 状态机

### Sprint 6 — Settlement 编排
- [ ] Payment Policy（单笔/日限额/类目/合约/Agent allowlist）
- [ ] Bilateral lock / confirm / payout / refund 编排
- [ ] 接线 `setTreasury` + `setFeeBridge`（§二）

### Sprint 7 — Trust（核心验证 · 不可外移）
- [ ] Evidence Bundle + hash（复用 EvidenceBundleBuilder）
- [ ] **VerificationEngine**（证据是否证明约定结果）
- [ ] Risk / Dispute
- [ ] **仅 Verification PASS → settle**

### Sprint 8 — Reputation + 经济可见
- [ ] 执行历史 / Agent 信誉
- [ ] Public Verification 视图
- [ ] settle 后 FeeBridge GMV 可查
- [ ] MiniApp 嵌入 karma8 经济面（Wallet / Rewards / Contrib）

### 安全硬性要求（方案 §三十一）
- [ ] 不存用户私钥
- [ ] 无无限 USDC approve
- [ ] 不信任前端金额 / 前端 tg id
- [ ] 不只依赖商家自传 Evidence
- [ ] Agent 不可绕过用户 Policy
- [ ] Nonce、Rate limit、Webhook 签名、Audit log

---

## 四、第一条真实交易验收链（两边一起）

```text
□ TG 打开 MiniApp → Session 识别 Identity
□ Chat 提交需求 → Intent → Discovery → Offer
□ 双方签名 → Policy 检查 → Lock USDC（Bilateral）
□ 执行 → 上传 Evidence → Verification PASS
□ Settle → FeeBridge.collectAndRecord
□ SettlementMirror 可见 GMV（冷启动 fee=0）
□ MiniApp /?view=miniapp 可见档位 / NFT weight / revenue 状态
□（可选）开启 revenue 后再测扣费与分红
```

---

## 五、给主仓 Cloud Agent 的一键指令

```text
在 AtoB101/Karma 按 karma8 仓库 integrations/telegram-miniapp/MAIN_BRIEF.md
与 docs/miniapp/Karma_Telegram_MiniApp_V1.0.txt 实现 Telegram MiniApp MVP。

必须：
1) initData 服务端验签 + SIWE Identity + Session
2) Chat Intent → Discovery → Order
3) Evidence + VerificationEngine（核心，不可省略）
4) Verification PASS 后才 Bilateral settle
5) 对接已有 feeBridge：setTreasury / setFeeBridge；冷启动 fee=0 仍 collectAndRecord
6) MiniApp Wallet/Rewards Tab 嵌入 karma8 /?view=miniapp

不要：在主仓实现国库费率、ContributionNFT mint 门槛、国库分账逻辑。
对齐清单：karma8 integrations/telegram-miniapp/ 与本文档。
```

---

## 六、karma8 侧已就绪（主仓可依赖）

| 能力 | 位置 |
|------|------|
| FeeBridge + SettlementMirror | `src/integration/` |
| Bilateral feeBridge 补丁（已合主仓） | Karma PR #141；校验 `verify_patch.sh` |
| Treasury / 质押 / 分红池 | `src/treasury`, `src/staking`, `src/pools` |
| Cocreation 计分链上 | `src/cocreation/` |
| MiniApp 经济面板 | `frontend/?view=miniapp` |
| 跨仓联调测试 | `integrations/karma-core/run_cross_repo_test.sh` |
