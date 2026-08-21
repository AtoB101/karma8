# Economy runtime（chain / RPC / 冷启动）

## 链与 RPC

| 网络 | chainId | 用途 |
|------|---------|------|
| Anvil / local | `31337` | `make demo-anvil` + `make demo-deploy` |
| Sepolia | `11155111` | 联调默认测试网 |
| Mainnet | `1` | 生产（revenue 默认仍建议先 false） |

```bash
# 根目录 .env（见 .env.example 全字段）
RPC_URL=
SEPOLIA_RPC_URL=
CHAIN_ID=11155111

# 前端 frontend/.env.local（或 npm run sync-addresses -- sepolia）
VITE_CHAIN_ID=11155111
VITE_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
```

## 清单 A — 地址字段

写入根 `.env` 与 `deployments/<network>.json`：

```text
TREASURY / FEE_BRIDGE / SETTLEMENT_MIRROR / STAKE / DEVELOPER_POOL / STAKER_POOL
CONTRIBUTION_NFT / CONTRIBUTOR_REGISTRY / CONTRIBUTION_LEDGER / COCREATION_SCORE_VIEW
KARMA_TOKEN / USDC / KARMA_BILATERAL (= KARMA_CORE_ADDRESS)
```

ABI：

```bash
make export-abis          # → abi/*.json + abi/manifest.json
# 前端子集：frontend/src/lib/abis.ts
```

## 冷启动（默认）

| 参数 | 值 | 说明 |
|------|-----|------|
| `Treasury.enableRevenueMode` | `false` | 部署默认 |
| `FeeBridge.quoteFee` / `quoteFeeBps` | `0` | revenue off 时 |
| `FEE_BPS` 常量 | `20`（0.2%） | **不可变**；开启后再按档位生效 |
| 分账 | 40/30/20/10 | 不可变 |
| DevPool | 70% GMV / 30% NFT | 不可变 |
| NFT mint 阈值 | 200 weight | `ContributionLedger` |

开启收费：仅 karma8 治理 `proposeEnableRevenue(true)` → 投票 → execute。主仓不改费率常量。

## FeeBridge ↔ Bilateral（B）

```bash
# 经济仓
forge script script/WireKarmaCore.s.sol --rpc-url $RPC_URL --broadcast

# 主仓 admin
# Bilateral.setTreasury(TREASURY)
# Bilateral.setFeeBridge(FEE_BRIDGE)

bash integrations/telegram-miniapp/verify_wiring.sh
```

约定：`orderId = bytes32(bindingId)`；`developer = builder_address`；fee=0 仍 `collectAndRecord`。

## Settlement Mirror（C）

`buyer == seller` → 记账单但不计 developer GMV。正常成交 GMV → `DeveloperRewardPool`。

## 嵌入（D）

```bash
KARMA8_ECONOMY_HOST=https://economy.example.com
MINIAPP_ORIGIN=https://miniapp.example.com,https://web.telegram.org,https://webk.telegram.org,https://webz.telegram.org
```

MiniApp iframe：`${KARMA8_ECONOMY_HOST}/?view=miniapp`  
静态 surface 样例：`${KARMA8_ECONOMY_HOST}/economy-surface.json`  
主仓 BFF：`GET /v1/economy/surface`（实现在主仓；字段见 `deployments/economy-surface.example.json`）。

Vite `frame-ancestors` + CORS 使用 `MINIAPP_ORIGIN`（见 `frontend/vite.config.ts`）。

## 联调验收（G）

见 `integrations/telegram-miniapp/ACCEPTANCE.md`。
