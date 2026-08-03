# 商业落地进度清单

更新目标：**≥95%**（见 [GO_LIVE_95.md](./GO_LIVE_95.md)）

## A. 协议与隔离

- [x] 不可变费率 / 分账常量
- [x] `enableRevenueMode` 默认 false + 回购暂停
- [x] Treasury 禁止私人转账
- [x] `FeeBridge` / `SettlementMirror` / `CoreEscrowAdapter` / `BilateralFeeHook`
- [x] 本地 `ReferenceSettlementCore` 飞轮 E2E
- [x] karma-core 可应用补丁包 + 锚点校验脚本
- [ ] Karma 仓库维护者合并补丁（无本 CI 写权限）

## B. 工程与安全

- [x] Foundry + CI（fmt/build/test）
- [x] 单元 / 集成 / 飞轮 / GoLiveAcceptance / 安全硬化 / 不变量
- [x] Certora 规格（Treasury / Stake）
- [x] Slither workflow + 配置
- [x] `DeployEconomy` / `DeployLocalDemo` / `DeploySepolia` / `BootstrapAllocations`
- [ ] 第三方审计报告（材料已就绪）

## C. 产品前端

- [x] 嵌入式页面组件
- [x] Vite 控制台（钱包连接 / 状态页 / 四业务页）
- [x] `frontend/scripts/sync-addresses.mjs` 同步本地部署地址
- [ ] 生产级订单索引看板（非上线阻塞项）

## D. 网络与运维

- [x] Chainlink Automation 配置脚本
- [x] 开关 / 对接 / 安全 / 95% 门禁文档
- [ ] Sepolia 实地址填表（部署后填写 INTEGRATION 地址表）

## 自动验收

```bash
forge test --match-contract GoLiveAcceptance -vv
```

期望：`GoLiveAcceptance` 12/12 检查通过（≥95%）。
