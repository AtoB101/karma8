# MiniApp 经济面（karma8 surface）

主仓 MiniApp **不托管**经济合约逻辑；通过 iframe / WebView / 深链打开本仓前端，或由 BFF 聚合只读 RPC。

## Embed

```text
https://<economy-host>/?view=miniapp
```

可选 query：

| 参数 | 含义 |
|------|------|
| `view=miniapp` | 启用紧凑 Telegram 布局 |
| `tab=wallet\|rewards\|contrib\|status` | 默认子页 |

Telegram WebApp：若存在 `window.Telegram.WebApp`，面板会 `ready()` / `expand()`；**身份验签仍在主仓**，本页只展示链上经济状态。

## 环境变量（Vite）

```bash
VITE_TREASURY=
VITE_STAKE=
VITE_GOVERNOR=
VITE_STAKER_POOL=
VITE_DEVELOPER_POOL=
VITE_CONTRIBUTION_NFT=
VITE_KARMA=
VITE_FEE_BRIDGE=
VITE_SETTLEMENT_MIRROR=
VITE_CONTRIBUTOR_REGISTRY=
VITE_CONTRIBUTION_LEDGER=
VITE_COCREATION_SCORE=
VITE_USDC=
```

`frontend/scripts/sync-addresses.mjs` 可从 `deployments/local.json` 同步。

## 面板能力（本仓）

| Tab | 链上数据 | 写操作 |
|-----|----------|--------|
| status | `enableRevenueMode`, `feeBps`, splits | 无 |
| wallet | stake tier, voting weight, feeBpsFor | 无（完整质押在主控制台） |
| rewards | staker `earned` / `pendingPoints` | `claim`（仅 revenue ON） |
| contrib | NFT `totalWeightOf`, ledger pending | 无（mint 经 ledger/主流程） |

## 主仓 BFF 可选聚合

```json
GET /v1/economy/surface?address=0x...
{
  "revenueMode": false,
  "feeBps": 20,
  "tier": 2,
  "nftWeight": 560,
  "pendingPoints": "0",
  "earnedUsdc": "0",
  "contracts": { "treasury": "0x...", "feeBridge": "0x..." }
}
```

实现时可直接 eth_call 本仓 ABI（`frontend/src/lib/abis.ts`）。

## 与 Verification 的关系

Verification **永不**在本 surface 执行。  
仅当主仓 Verification PASS → Bilateral settle → FeeBridge 后，本页 GMV / 分红数据才会变化。
