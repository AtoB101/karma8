# 95% 商业落地验收门禁

## 分数模型

| 板块 | 权重 | 本仓库可达 | 说明 |
|------|------|------------|------|
| 协议与不可变约束 | 20 | 20 | 费率/分账/开关/隔离 |
| 经济飞轮闭环 | 20 | 20 | E2E + GoLiveAcceptance |
| karma-core 对接 | 20 | 19 | 可应用 unified diff + DeployEconomy/WireKarmaCore/CoreLinkage；待 Karma 维护者合入补丁 |
| 安全工程 | 15 | 14 | 硬化测试+Certora 规格+Slither；外部审计报告待出 |
| 部署与运维 | 10 | 10 | Demo/Sepolia 脚本+开关手册+Automation 配置 |
| 前端控制台 | 10 | 9 | Vite 控制台可用；生产索引看板可选增强 |
| 合规审计签字 | 5 | 4 | 材料齐全；第三方签字在审计完成后 |

**仓库内可自动验收目标：≥95/100（GoLiveAcceptance 12/12）。**  
剩余 ~5%：Karma 侧合入补丁 + 外部审计签字 +（可选）生产索引服务。

## 一键验收

```bash
forge test --match-contract GoLiveAcceptance -vv
forge test --match-contract FlywheelE2E -vv
forge test --match-contract CoreLinkage -vv
forge test --match-contract SecurityHardening -vv
bash integrations/karma-core/verify_patch.sh
```

## 跨仓库最后一公里（维护者操作，约 1 小时）

1. 在 `AtoB101/Karma` 应用 `integrations/karma-core/patches/0001-add-treasury-feebridge.diff`
2. Sepolia 部署 economy，接线 `setFeeBridge` / `FeeBridge.setCore`
3. 预约审计；Certora 使用 `certora/conf/Treasury.conf`（需 `CERTORAKEY`）
4. 治理演练后保持 `enableRevenueMode=false` 进入冷启动
