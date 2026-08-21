# 商业落地进度清单

对齐标准：[`commercial/COMMERCIAL_STANDARD.md`](./commercial/COMMERCIAL_STANDARD.md)

## 阶段

| 阶段 | 状态 |
|------|------|
| P0 技术闭环 | 本仓代码具备 |
| P1 公开冷启动（商业试点） | 代码+官网+门禁就绪；**你需完成 USER_OPS + 主仓要求** |
| P2 正式收费 | 门禁脚本支持；须观察期 + 治理开启 |

## A. 协议与隔离

- [x] 不可变费率 / 分账常量
- [x] `enableRevenueMode` 默认 false + 回购暂停
- [x] Treasury 禁止私人转账
- [x] FeeBridge / Mirror / Escrow（fail-hard）/ fee==quote / orderId 幂等
- [x] 特权角色禁止自领
- [x] karma-core 补丁已合主仓 PR #141

## B. 工程与安全

- [x] Foundry + CI + SecurityHardening + SecurityAuditRegression
- [x] 安全审计报告 `docs/security/SECURITY_AUDIT_2026-08-21.md`
- [x] `make commercial-check`
- [ ] 第三方审计（P2 强烈建议）

## C. 产品 / 官网 / TG

- [x] 官网 Landing（`/`）
- [x] MiniApp 经济面 `/?view=miniapp`
- [x] 控制台 `/?view=console`
- [x] `/health.json` + CSP / nginx 模板
- [ ] 生产 HTTPS 域名与 Bot（**你的 OPS**）

## D. 运维

- [x] `OPS_RUNBOOK.md`
- [x] 主仓商业要求清单
- [ ] 生产监控告警接入（按手册配置）

## 自动验收

```bash
make commercial-check
forge test --match-contract GoLiveAcceptance -vv
```
