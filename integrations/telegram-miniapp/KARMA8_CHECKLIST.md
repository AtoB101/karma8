# karma8 联调清单（A–G）

主仓对齐依据：对方提供的 karma8 任务列表。  
状态：`DONE` = 仓库已具备；`OPS` = 需部署/填真实地址后执行。

总览文档：`docs/ECONOMY_RUNTIME.md` · 验收：`ACCEPTANCE.md`

---

## A. 部署地址（阻塞联调）

| 项 | 状态 | 位置 |
|----|------|------|
| env 全字段模板 | DONE | `.env.example`、`frontend/.env.example` |
| 地址 schema / Sepolia 模板 | DONE | `deployments/addresses.schema.json`、`sepolia.example.json` |
| 本地 demo 写出 JSON | DONE | `DeployLocalDemo` → `deployments/local.json`（含 `karmaBilateral`） |
| ABI 导出（对齐 frontend） | DONE | `make export-abis` → `abi/*.json`；子集 `frontend/src/lib/abis.ts` |
| chainId / RPC / 冷启动 fee | DONE | `docs/ECONOMY_RUNTIME.md` |

**OPS：** 测试网部署后写入 `.env` + `deployments/<network>.json`，再 `cd frontend && npm run sync-addresses -- sepolia`。

---

## B. FeeBridge ↔ Bilateral

| 项 | 状态 | 位置 |
|----|------|------|
| `FeeBridge.setCore(Bilateral)` | DONE | `DeployEconomy` / `WireKarmaCore.s.sol` |
| Bilateral `setTreasury` / `setFeeBridge` | DONE 主仓；本仓文档 | `integrations/karma-core/APPLY.md` |
| fee=0 仍记 GMV | DONE 测试 | `CoreLinkage` / `run_cross_repo_test.sh` |
| `orderId=bytes32(bindingId)` · `developer=builder` | DONE 约定 | `docs/INTEGRATION.md` |
| 接线校验脚本 | DONE | `make verify-wiring` |

**OPS：** 部署后 `WireKarmaCore` + 主仓 admin set；跑 `verify_wiring.sh`。

---

## C. Settlement Mirror

| 项 | 状态 | 位置 |
|----|------|------|
| `buyer==seller` 不计 developer GMV | DONE | `SettlementMirror.recordBill` + Cocreation 测试 |
| 正常 GMV → DevPool | DONE | `DeveloperRewardPool`（70/30） |

---

## D. 经济面嵌入

| 项 | 状态 | 位置 |
|----|------|------|
| `/?view=miniapp` | DONE | `MiniAppEconomyPage.tsx` |
| CORS / CSP frame-ancestors / `MINIAPP_ORIGIN` | DONE | `frontend/vite.config.ts` |
| `KARMA8_ECONOMY_HOST` | DONE | `.env.example` + runtime 文档 |
| surface 配置 | DONE | `deployments/economy-surface.example.json`、`frontend/public/economy-surface.json` |
| 视图无 VerificationEngine | DONE | 仅 status/wallet/rewards/contrib |

---

## E. 共创激励（V1）

| 项 | 状态 | 位置 |
|----|------|------|
| mint 阈值 200 | DONE | `ContributionLedger` / `MINT_THRESHOLD_WEIGHT` |
| 70% GMV / 30% NFT | DONE | `DeveloperRewardPool` |
| `COCREATION_SCORE_VIEW` 可读 | DONE | `CocreationScoreView` + ABI |

---

## F. revenueMode

| 项 | 状态 | 位置 |
|----|------|------|
| 默认 false（冷启动 fee 报价 0） | DONE | `Treasury` / `FeeBridge.quoteFeeBps` |
| 切换只在 karma8 治理 | DONE | `KarmaGovernor.proposeEnableRevenue` |
| 主仓不改 FEE_BPS | DONE | 无 setter |

---

## G. 联调验收

见 `ACCEPTANCE.md` · 多场景实测：`TELEGRAM_SCENARIOS.md`

```bash
RESET_ANVIL=1 make tg-demo   # 干净 anvil + deploy + seed S1/S2/S4/S5
cd frontend && npm run dev
# mock TG: http://127.0.0.1:5173/tg-shell.html
# MiniApp:  http://127.0.0.1:5173/?view=miniapp
```

**明确不在主仓做：** Treasury fee/split、NFT mint 阈值、pool claim 细节、FeeBridge/Mirror 内部、完整链上代发（本仓前端钱包 / 可选 relayer）。
