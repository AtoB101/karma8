# 95% 商业落地验收门禁

## 分数模型

| 板块 | 权重 | 本仓库可达 | 说明 |
|------|------|------------|------|
| 协议与不可变约束 | 20 | 20 | 费率/分账/开关/隔离 |
| 经济飞轮闭环 | 20 | 20 | E2E + GoLiveAcceptance |
| karma-core 对接 | 20 | 20 | Karma PR #141 已合入 feeBridge；CrossRepo + CoreLinkage 验收通过 |
| 安全工程 | 15 | 14 | 硬化测试+Certora 规格+Slither；外部审计报告待出 |
| 部署与运维 | 10 | 10 | Demo/Sepolia 脚本+开关手册+Automation 配置 |
| 前端控制台 | 10 | 9 | Vite 控制台可用；生产索引看板可选增强 |
| 合规审计签字 | 5 | 4 | 材料齐全；第三方签字在审计完成后 |

**仓库内可自动验收目标：≥95/100（GoLiveAcceptance 12/12）。**  
剩余缺口主要为外部审计签字与（可选）生产索引服务。

## 一键验收

```bash
forge test --match-contract GoLiveAcceptance -vv
forge test --match-contract FlywheelE2E -vv
forge test --match-contract CoreLinkage -vv
forge test --match-contract SecurityHardening -vv
bash integrations/karma-core/verify_patch.sh
bash integrations/karma-core/run_cross_repo_test.sh   # live Bilateral x FeeBridge
```

## 链上接线（部署后）

1. karma8：`DeployEconomy`（`KARMA_CORE_ADDRESS=Bilateral`）
2. Karma：`Bilateral.setTreasury(Treasury)` + `setFeeBridge(FeeBridge)`
3. 冷启动保持 `enableRevenueMode=false`；治理后再开收费
4. 预约审计；Certora 使用 `certora/conf/Treasury.conf`（需 `CERTORAKEY`）