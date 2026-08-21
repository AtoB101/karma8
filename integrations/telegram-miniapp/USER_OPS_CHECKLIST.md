# 你需要完成的事项（正式运营）

> karma8 侧代码 / 合约 hardening / 经济面 / 安全 Critical 已就绪（见 PR #6+#7+#本分支）。  
> **下面每一项只能由你（或主仓运维）完成**——我无法代替你持有 Bot Token、域名、私钥或多签。

按顺序勾选。全部勾完 = 可以正式在 Telegram 运营（建议先冷启动 `enableRevenueMode=false`）。

---

## A. 合并代码

- [ ] 合并 karma8 PR：**MiniApp / A–G**（#6）、**安全 Critical**（#7）、**Go-live hardening**（本分支 PR）
- [ ] 确认主仓 `AtoB101/Karma` 已含：initData 验签、SIWE、Order、VerificationEngine、Bilateral `setTreasury`/`setFeeBridge`、settle → `collectAndRecord`

---

## B. 链上部署（测试网 → 再主网）

- [ ] 准备部署钱包 / 多签 7 人地址，填入 karma8 `.env`（参考 `.env.example`）
- [ ] 填 `USDC_ADDRESS`、`KARMA_BILATERAL`（主仓 Bilateral 地址）
- [ ] 跑 `forge script script/DeployEconomy.s.sol:DeployEconomy --rpc-url $RPC_URL --broadcast`
- [ ] 把产物写入 `deployments/<network>.json` 与双方 env（清单 A 全字段）
- [ ] 主仓 admin：`Bilateral.setTreasury(TREASURY)` + `setFeeBridge(FEE_BRIDGE)`
- [ ] 跑 `make verify-wiring` → **RESULT: OK**
- [ ] 确认 `Treasury.enableRevenueMode() == false`（冷启动）

---

## C. 经济面前端上线（HTTPS）

- [ ] 申请域名，例如 `https://economy.yourdomain.com`（**必须 HTTPS**）
- [ ] `cd frontend && npm i && npm run sync-addresses -- <network> && MINIAPP_ORIGIN=... npm run build`
- [ ] 部署 `frontend/dist`（Cloudflare Pages / nginx；参考 `deploy/nginx.economy.conf.example`、`frontend/public/_headers`）
- [ ] 浏览器打开：`https://economy.yourdomain.com/?view=miniapp` 能加载
- [ ] Response 头含 `Content-Security-Policy: frame-ancestors ...`（含 Telegram + 主仓 MiniApp）
- [ ] 设环境变量：
  - `KARMA8_ECONOMY_HOST=https://economy.yourdomain.com`
  - `MINIAPP_ORIGIN=https://web.telegram.org,https://webk.telegram.org,https://webz.telegram.org,https://<主仓MiniApp域名>`

---

## D. Telegram Bot + 主仓 MiniApp

- [ ] 用 [@BotFather](https://t.me/BotFather) 创建 Bot，保存 **Bot Token**（勿发聊天 / 勿进 git）
- [ ] 主仓配置 Token + `setWebhook`（HTTPS webhook URL）
- [ ] MiniApp MenuButton / WebApp URL：主仓 MiniApp 入口（内嵌或跳转）
  - Wallet / Rewards Tab → `https://economy.yourdomain.com/?view=miniapp`
- [ ] 主仓 BFF：`KARMA8_ECONOMY_HOST` 同上；可选 `GET /v1/economy/surface`
- [ ] 真机 Telegram 打开 Bot → MiniApp → 能看到经济面（iframe）

---

## E. 首条真实交易验收（冷启动）

- [ ] TG 内完成：Session / SIWE / 下单 / Evidence / **Verification PASS** → settle
- [ ] 链上：`FeeBridge.collectAndRecord` 成功；`SettlementMirror` 有账单；**fee=0**
- [ ] 自成交单：developer GMV **不增加**
- [ ] 正常单：builder GMV 增加；经济面状态可见
- [ ] 无私钥泄露、无无限 approve、金额以链上 / 主仓签名为准

---

## F. 运营开关（开收费前再做）

- [ ] 冷启动稳定 ≥ 你定的观察期后再治理开启 `enableRevenueMode`
- [ ] BUILDER 角色仅通过治理 `registerFor` / `setRoles` 发放（自注册已禁止特权角色）
- [ ] 多签 / 部署私钥离线保管；轮换 Bot Token 权限最小化
- [ ] （建议）主网上线前做一次外部审计或至少再跑 `make security-audit`

---

## 我（karma8）已替你做好的

| 能力 | 位置 |
|------|------|
| FeeBridge / Mirror / 冷启动 / 自成交规则 | 合约 |
| 安全 Critical 修复 + 回归测试 | PR #7 |
| BUILDER 等特权角色禁止自领 | Go-live 分支 |
| Escrow 失败不再静默成功 | CoreEscrowAdapter |
| MiniApp 嵌入 + CORS/CSP 模板 | frontend + nginx/_headers |
| 写操作 chainId / 地址校验 | frontend |
| 联调清单 / 场景指南 | `integrations/telegram-miniapp/` |

**你不需要在主仓重做：** Treasury 费率、分账、NFT mint 阈值、池子 claim 细节、FeeBridge/Mirror 内部。
