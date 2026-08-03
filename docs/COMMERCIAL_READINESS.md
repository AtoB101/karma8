# 商业落地进度清单

## 当前阶段目标

把 karma-economy 从「合约骨架」推进到「可联调、可演示、可审计」的冷启动待命态。

## 清单

### A. 协议与隔离（本仓库）

- [x] 不可变费率 / 分账常量
- [x] `enableRevenueMode` 默认 false + 回购暂停
- [x] Treasury 禁止私人转账
- [x] `FeeBridge` / `SettlementMirror` / `CoreEscrowAdapter`
- [x] 本地 `ReferenceSettlementCore` 飞轮 E2E
- [x] karma-core 最小补丁说明（`integrations/karma-core/PATCH.md`）

### B. 工程交付

- [x] Foundry 工程 + CI
- [x] 单元 / 集成 / 飞轮 E2E / 质押不变量测试
- [x] `DeployEconomy` / `DeployLocalDemo` / `BootstrapAllocations`
- [x] 部署、对接、开关、安全文档

### C. 产品前端

- [x] 嵌入式页面组件（质押/节点/治理/NFT）
- [x] 可独立运行的 Vite demo 控制台（wagmi + 环境变量地址）
- [ ] 生产控制台（索引、订单、运营看板）

### D. 跨仓库与网络

- [ ] 将 PATCH 合入 `AtoB101/Karma`（KarmaBilateral）
- [ ] Sepolia 部署 economy + 配置 core treasury/feeBridge
- [ ] Chainlink Automation 注册
- [ ] Uniswap 池与主网回购参数

### E. 上线门禁

- [ ] 专业审计
- [ ] Certora / 形式化验证关键不变量
- [ ] 测试网：开启→验证→关闭 回归签字
- [ ] 多签 7 席位与轮换流程演练
- [ ] 冷启动 GMV 达标后治理开启盈利

## 建议下一迭代（跨仓库）

1. 在 `AtoB101/Karma` 合入 treasury/feeBridge 最小补丁  
2. Sepolia 联调：Bilateral settle → FeeBridge → Treasury  
3. 审计 + 不变量证明  
4. 完整运营前端与监控
