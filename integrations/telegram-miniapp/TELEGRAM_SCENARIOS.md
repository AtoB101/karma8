# Telegram 多场景实测指南（karma8）

目标：把经济面接到 Telegram MiniApp，覆盖冷启动结算、自成交、GMV、嵌入面板。

验证 / SIWE / Bot webhook 在**主仓**；本仓提供可嵌入 URL + 链上场景种子。

---

## 一、本地一键（推荐先跑通）

```bash
# 根目录
bash integrations/telegram-miniapp/run_tg_local_demo.sh
# 或
make tg-demo

cd frontend && npm i && npm run dev
```

| URL | 用途 |
|-----|------|
| `http://127.0.0.1:5173/?view=miniapp` | 经济面 |
| `http://127.0.0.1:5173/tg-shell.html` | 模拟 Telegram 父页 iframe |
| `http://127.0.0.1:5173/economy-surface.json` | 主仓 BFF surface 样例 |

钱包：MetaMask 添加 `Localhost 8545` / chainId `31337`，导入 Anvil #0 私钥（仅本地）。

种子数据：`deployments/scenarios.json`  
接线校验：`make verify-wiring`

---

## 二、多场景清单

| # | 场景 | 链上期望 | MiniApp 怎么看 |
|---|------|----------|----------------|
| S1 | 冷启动正常成交 | `fee=0`，`lifetimeDeveloperGmv(builder)` ↑ | 状态：盈利 OFF；连接 builder 相关地址看 GMV |
| S2 | 自成交 `buyer==seller` | 有账单，**GMV 不增加** | `scenarios.selfDealDidNotCreditGmv=true` |
| S3 | 嵌入壳 | iframe 可加载 | `tg-shell.html` 或主仓 iframe |
| S4 | 钱包档位 | deployer 已质押 Developer | Tab「钱包」 |
| S5 | 贡献/BUILDER | registry Active + BUILDER | Tab「贡献」「钱包」 |
| S6 | 开收费（可选） | 治理 `enableRevenueMode` | 状态 ON；再 settle 才扣费 |
| S7 | 真 Telegram | HTTPS + Bot MenuButton / 主仓嵌 | 见第三节 |

本地种子已自动跑 **S1+S2+S4+S5**。

---

## 三、接入真 Telegram（主仓 + karma8）

### 3.1 经济面 HTTPS

Telegram WebApp 要求 **HTTPS** 公网地址：

```bash
# 例：cloudflared
cloudflared tunnel --url http://127.0.0.1:5173
# 或 ngrok http 5173
```

```bash
# 根 .env / 前端
KARMA8_ECONOMY_HOST=https://xxxx.trycloudflare.com
MINIAPP_ORIGIN=https://web.telegram.org,https://webk.telegram.org,https://webz.telegram.org,https://<main-miniapp-host>
```

重启 `npm run dev`（或生产 `vite preview` / 静态托管）。

### 3.2 主仓配置

```text
KARMA8_ECONOMY_HOST=<同上>
embed: ${KARMA8_ECONOMY_HOST}/?view=miniapp
GET /v1/economy/surface → 读 economy-surface.json 或 eth_call abi/
```

Bot：`setWebhook`、initData 验签、Session — **仅主仓**。  
Wallet / Rewards Tab → iframe 本仓 MiniApp。

### 3.3 测网 / 主网地址

1. `DeployEconomy` 到 Sepolia  
2. 填 `deployments/sepolia.json` + `.env`  
3. 主仓 Bilateral `setTreasury` + `setFeeBridge`  
4. `make verify-wiring`  
5. `npm run sync-addresses -- sepolia`  
6. 主仓走真实：Session → Order → Verify PASS → settle → 打开经济面看 GMV

---

## 四、主仓联调对照（G）

| 主仓 | karma8 |
|------|--------|
| Verify PASS → finalize | Bilateral/`ReferenceCore` settle → `collectAndRecord` |
| 标 self_deal | Mirror GMV 不变 |
| embed_url | `/?view=miniapp` 打开 |
| Bot webhook | 主仓；本仓 CORS/CSP 已按 `MINIAPP_ORIGIN` |

---

## 五、命令速查

```bash
make tg-demo              # anvil + deploy + seed + sync + verify
make export-abis
make verify-wiring
cd frontend && npm run dev
```
