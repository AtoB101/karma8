# Telegram 正式运营 — karma8 就绪说明

## 状态

karma8 已具备正式运营所需的**经济侧**能力（合约 + MiniApp + 安全 Critical + 生产头模板）。  
是否「已经在 Telegram 上运营」，取决于你完成 [`USER_OPS_CHECKLIST.md`](./USER_OPS_CHECKLIST.md)。

```text
用户 Telegram
  → 主仓 Bot / MiniApp（Identity · Order · Verification）
  → Bilateral.settle → FeeBridge.collectAndRecord
  → Treasury / Mirror / 分红池
  → 经济面 iframe: KARMA8_ECONOMY_HOST/?view=miniapp
```

## 冷启动默认

- `enableRevenueMode = false`
- settle **fee=0**，仍记 GMV
- 分红 claim 锁定，直到治理开启盈利模式

## 生产构建注意

```bash
export MINIAPP_ORIGIN="https://web.telegram.org,https://webk.telegram.org,https://webz.telegram.org,https://YOUR_MAIN_HOST"
cd frontend && npm run build   # production 未设 MINIAPP_ORIGIN 会失败（有意）
```

部署后用 curl 检查：

```bash
curl -sI https://economy.yourdomain.com/ | grep -i content-security-policy
```

## 相关文档

- 你的操作清单：`USER_OPS_CHECKLIST.md`
- 场景实测：`TELEGRAM_SCENARIOS.md`
- 安全审计：`docs/security/SECURITY_AUDIT_2026-08-21.md`
- 运行时：`docs/ECONOMY_RUNTIME.md`
