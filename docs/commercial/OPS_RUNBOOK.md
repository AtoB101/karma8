# 商业运营手册（karma8）

## 职责

| 角色 | 负责 |
|------|------|
| 链上经济 | Treasury / FeeBridge / 池 / 质押 |
| 站点 | 官网 + MiniApp 经济面 HTTPS |
| 结算触发 | 主仓 Bilateral（本仓只接收 FeeBridge） |

## 日常巡检（每日 / 自动化）

```bash
# 接线
export RPC_URL=... FEE_BRIDGE_ADDRESS=... SETTLEMENT_MIRROR_ADDRESS=... TREASURY_ADDRESS=... KARMA_BILATERAL=...
make verify-wiring

# 门禁
make commercial-check

# 站点
curl -fsS "$KARMA8_ECONOMY_HOST/health.json" | jq .
curl -fsSI "$KARMA8_ECONOMY_HOST/" | grep -i content-security-policy
```

告警建议：
- `health.json` 5xx 或拉取失败
- `FeeBridge.core != KARMA_BILATERAL`
- `enableRevenueMode` 非预期翻转
- RPC 延迟 / 错误率

## 事故分级

| 级别 | 例子 | 动作 |
|------|------|------|
| Sev1 | settle 大面积失败 / 错扣费 | 停 Bot 新单；查 FeeBridge/Bilateral；回滚前端若误配 |
| Sev2 | MiniApp 嵌失败 / CSP | 修 CDN headers；临时主仓深链 |
| Sev3 | 单笔 GMV 异常 | 核对 orderId / self_deal；冻结相关 builder 角色 |

## 开收费（P2）

1. `ENABLE_REVENUE_CHECKS=1 make commercial-check`
2. 确认观察期指标达标
3. 治理 `proposeEnableRevenue(true)` → 投票 → execute
4. 小额真单验证扣费与分账
5. 公告用户；监控 Treasury 余额与池 notify

## 回滚收费

治理 `proposeEnableRevenue(false)`；新单回 fee=0；已分账资金按池规则 claim，不支持任意退回协议外用户。
