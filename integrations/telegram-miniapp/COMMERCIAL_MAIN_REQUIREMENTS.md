# 商业化 — 主仓库硬性要求

转发给 `AtoB101/Karma`。未完成则 **不能** 宣称已达 P1 商业试点。

## 必须交付

1. **Bot + MiniApp**
   - BotFather Token；HTTPS `setWebhook`
   - **initData HMAC 服务端验签**（强制）
   - MenuButton / WebApp 入口

2. **Identity**
   - SIWE；karma_identity；Session 过期与防重放
   - 禁止只信前端 `tg user id`

3. **交易与信任**
   - Intent → Discovery → Quote/Order → 双方签名
   - Payment Policy（限额/类目/合约/Agent allowlist）
   - Evidence + **VerificationEngine**
   - **仅 Verification PASS → Bilateral.settle**

4. **经济接线**
   - `setTreasury` + `setFeeBridge`
   - settle：`fee = quoteFee(...)` 后 `collectAndRecord`（精确相等）
   - `orderId = bytes32(bindingId)`；`developer = builder`
   - 冷启动 fee=0 仍 collectAndRecord
   - 配置 `KARMA8_ECONOMY_HOST`；Wallet/Rewards iframe → `/?view=miniapp`

5. **安全**
   - 不存用户私钥；无无限 approve；Agent 不可绕过 Policy
   - Rate limit、Webhook 签名、Audit log

## 明确不做（在 karma8）

Treasury 费率/分账、NFT mint 阈值、pool claim 细节、FeeBridge/Mirror 内部。

## P1 验收（主仓签字）

```text
□ TG 打开 Bot → MiniApp 有 Session
□ 完整一单 Verify PASS → settle 上链
□ FeeBridge/Mirror 可见；冷启动 fee=0
□ 经济面 iframe 正常
□ 故意错 fee / 重放 orderId 会失败（与 karma8 加固一致）
```
