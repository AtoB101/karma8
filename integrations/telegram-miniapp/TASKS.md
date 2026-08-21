# Dual-repo task board — Telegram MiniApp

## karma8（本仓）— 本 PR

- [x] 双仓分工文档 `docs/MINIAPP_DUAL_REPO.md`
- [x] 主仓简报 `integrations/telegram-miniapp/MAIN_BRIEF.md`
- [x] 经济面嵌入说明 `ECONOMY_SURFACE.md`
- [x] MiniApp 经济面板 `?view=miniapp`
- [x] ABI / 地址扩展（FeeBridge、Ledger、Registry、DevPool、Score）
- [x] sync-addresses 支持新字段
- [ ] Sepolia 部署后填写真实地址到 deployments/

## Karma 主仓 — 待开 Agent / PR

粘贴 `MAIN_BRIEF.md` §7 指令。优先：

1. Sprint 1–2：SIWE + Telegram initData 验签 + Session  
2. Sprint 5–7：Order → Evidence → **Verification** → Bilateral settle  
3. 嵌入 karma8 `?view=miniapp` 作为 Wallet/Rewards Tab  

## 验收一条链

TG Chat → Lock → Evidence → Verify PASS → Settle → FeeBridge GMV → MiniApp 经济面可见 stake/NFT/revenue
