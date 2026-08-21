# 联调验收（G）

## 前置

- [ ] karma8 地址已写入双方 env（清单 A）
- [ ] `make export-abis` 已跑；主仓可用 `abi/*.json` 或 `frontend/src/lib/abis.ts`
- [ ] `FeeBridge.core == KARMA_BILATERAL`
- [ ] Bilateral 已 `setTreasury` + `setFeeBridge`
- [ ] `Treasury.enableRevenueMode() == false`（冷启动）
- [ ] `MINIAPP_ORIGIN` / `KARMA8_ECONOMY_HOST` 已配

## 主仓已就绪时，karma8 执行

| 主仓步骤 | karma8 验收 |
|----------|-------------|
| Session / SIWE / bind | 无（主仓） |
| Registry → Order | 无（主仓） |
| Verify PASS → finalize | 触发 Bilateral settle |
| Bilateral settle | `FeeBridge.collectAndRecord` 成功；`SettlementMirror` 有账单 |
| 标注 `self_deal`（buyer==seller） | Mirror **developer GMV 不增加**；账单仍可查 |
| 正常成交 | `lifetimeDeveloperGmv(builder)` 或区间 GMV > 0；DevPool preview 可用 |
| `embed_url` | 打开 `KARMA8_ECONOMY_HOST/?view=miniapp`（余额/claim/NFT，无 Verification） |
| Bot webhook API | **主仓** `setWebhook` + Bot Token；本仓只保证 CORS/CSP |

## 一键检查（有 cast + 地址时）

```bash
export RPC_URL=...
export FEE_BRIDGE_ADDRESS=...
export SETTLEMENT_MIRROR_ADDRESS=...
export TREASURY_ADDRESS=...
export KARMA_BILATERAL=...   # or KARMA_CORE_ADDRESS
make verify-wiring
```

## 冷启动 → 开收费（F）

1. 冷启动 settle：fee=0，GMV 有镜像  
2. 治理开启 `enableRevenueMode`（仅 karma8）  
3. 再 settle：Treasury 收到 fee；claim 解锁（需 epoch 分账）

## 边界

不在主仓做：Treasury fee/split、NFT mint 阈值、pool claim 细节、FeeBridge/Mirror 内部实现、完整链上代发。
