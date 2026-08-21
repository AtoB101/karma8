# Telegram MiniApp × 双仓库分工（V1）

来源方案：[`docs/miniapp/Karma_Telegram_MiniApp_V1.0.txt`](./miniapp/Karma_Telegram_MiniApp_V1.0.txt)

## 原则

| 仓库 | 职责 | 禁止 |
|------|------|------|
| **AtoB101/Karma（主仓）** | Bot / MiniApp 壳、initData 校验、Identity、Discovery、Commerce、**Evidence / Verification**、Settlement 编排、Agent | 把费率/国库逻辑写进主仓业务合约 |
| **AtoB101/karma8（本仓）** | FeeBridge / Treasury / Stake / NFT / Cocreation；**经济面板**（只读+领奖/质押）；地址与 ABI 供给 MiniApp | 实现 VerificationEngine / Chat / Discovery |

```text
Telegram MiniApp (主仓前端)
        │ session / karma_identity
        ▼
   Karma API (主仓) ── Evidence → Verification → Bilateral settle
        │                                         │
        │                                         ▼ FeeBridge
        └── embed / deep-link ──► karma8 Economy Surface
                                  (stake · claim · NFT weight · revenue flag)
```

## 本仓交付（本 PR）

1. `frontend` MiniApp 经济面板（`?view=miniapp`）
2. 扩展 ABI / 地址环境变量（FeeBridge、Mirror、Registry、Ledger、Score、DevPool）
3. `integrations/telegram-miniapp/MAIN_BRIEF.md` — 给主仓的实现简报
4. `integrations/telegram-miniapp/ECONOMY_SURFACE.md` — 主仓如何嵌入经济面

## 主仓必须保留的核心验证

方案 §二十 / §二十一 / Sprint 7：

- Evidence Bundle + hash
- VerificationEngine（是否足以证明约定结果）
- Risk / Dispute
- Settlement 仅在 Verification = PASS 后触发

本仓**不**复制 Verification；settle 成功后只经已有 FeeBridge 记账 / 抽费。

## MVP 垂直建议（与方案一致）

先做一条链：AI Agent / 软件服务 · 锁 100 USDC · Evidence · Verify · Settle · 经济镜像 GMV。
