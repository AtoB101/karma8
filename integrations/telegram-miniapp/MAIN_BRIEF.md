# Karma 主仓：Telegram MiniApp MVP 实现简报

> 目标仓库：`AtoB101/Karma`  
> 经济仓库：`AtoB101/karma8`（只提供结算后的 FeeBridge / 收益面板）  
> 完整产品文：karma8 `docs/miniapp/Karma_Telegram_MiniApp_V1.0.txt`

## 0. 硬边界

**必须在主仓实现（核心验证）：**

- Telegram `initData` 服务端校验（绝不信前端 tg user id）
- Karma Identity / SIWE / Telegram binding / Session
- Discovery · Quote · Order · Intent Package
- EvidenceBundleBuilder · **VerificationEngine** · Risk · Dispute
- Bilateral lock / settle 编排（已有 feeBridge 对接）

**不得在主仓重做：**

- 手续费常量 / 国库分账 / ContributionNFT mint 门槛  
  → 调用 karma8 已部署合约

## 1. Sprint 映射（主仓）

| Sprint | 主仓模块 | 验收切片 |
|--------|----------|----------|
| 1 Identity | SIWE + karma_identity + wallet | 官网连钱包 → Identity Dashboard |
| 2 Telegram | Bot + MiniApp + initData + session | 绑定 TG → MiniApp 自动识别 Identity |
| 3 Registry | business / agent / capability / offer | 商家注册 Capability |
| 4 Discovery | intent parse + rank | Chat 一句需求 → Offer 列表 |
| 5 Commerce | quote / negotiate / order / bill | 双方签名 Intent |
| 6 Settlement | policy + lock + payout | Policy 过 → Lock USDC |
| **7 Trust** | **Evidence + Verification + Risk** | **Verify PASS 才 settle** |
| 8 Reputation | execution history + public verify | settle 后信誉更新；GMV 进 karma8 Mirror |

## 2. 建议目录（主仓）

```text
apps/telegram_miniapp/          # Mini App 前端（Chat / Activity / Identity）
apps/karma_bff/                 # 已有 BFF 扩展 telegram auth
services/telegram/              # bot webhook, initData verify
services/identity_gateway/
trust/verification/             # 复用 VerificationEngine
trust/evidence/
settlement/                     # 编排 Bilateral + 读 karma8 地址
```

## 3. API 最小集（MVP）

```text
POST /v1/auth/siwe/challenge|verify
POST /v1/telegram/bind          # initData + challenge
POST /v1/telegram/session       # initData → session
POST /v1/chat/intent
GET  /v1/discovery/offers
POST /v1/commerce/orders
POST /v1/evidence/bundles
POST /v1/verification/runs      # ★ 核心
POST /v1/settlement/lock|finalize
GET  /v1/economy/surface        # 代理或深链到 karma8 面板配置
```

## 4. Settlement → karma8

结算成功后（Bilateral 已合入 feeBridge）：

1. `FeeBridge.collectAndRecord`（冷启动 fee=0 仍记 GMV）
2. MiniApp Activity 展示 order 状态
3. Identity / Wallet Tab 嵌入 karma8 `?view=miniapp`（质押、NFT weight、revenue 开关只读）

地址清单由 karma8 `DeployEconomy` / `deployments/*.json` 提供，字段见 `ECONOMY_SURFACE.md`。

## 5. 安全清单（主仓必做）

方案 §三十一：initData 验签、nonce、session 过期、SIWE、Policy 限额、allowlist、禁止存私钥、禁止无限 USDC approve。

## 6. 第一条真实交易链（验收）

```text
TG → Identity → Chat → Intent → Offer → Lock 100 USDC
  → Execute → Evidence → Verification PASS → Settle
  → FeeBridge GMV mirror →（可选）Cocreation / 分红面板可见
```

## 7. 给主仓 Agent 的一句话指令

```text
在 AtoB101/Karma 实现 Telegram MiniApp MVP：Bot + initData 服务端校验 +
Identity/Session + Chat Intent + Discovery/Offer + Order + Evidence +
VerificationEngine（核心）+ Bilateral settlement。不要实现国库/费率；
结算后对接 karma8 FeeBridge。经济 UI 嵌入 karma8 frontend ?view=miniapp。
规格见 karma8 docs/miniapp/Karma_Telegram_MiniApp_V1.0.txt 与
integrations/telegram-miniapp/MAIN_BRIEF.md。
```
