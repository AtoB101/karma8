# 安全与合规红线

## 审计要求

- 主网上线前必须通过专业安全审计
- 建议对分账、质押罚没、治理执行路径做 Certora 形式化验证

## 已落地的安全机制

- 资金流转合约使用 `ReentrancyGuard`
- 多签：资金操作 ≥5/7，控制器操作 7/7
- `Treasury` 禁止私人地址任意转账（`transfer` 永久 revert）
- 费率与分账比例为 `KarmaEconomyConstants` 常量，无 setter
- `KarmaGovernor` 拦截 `setFeeBps` / `setSplitRatios` 选择器
- `enableRevenueMode` 默认 `false`；`AutoBuyBurn.swapPaused` 默认 `true`

## 行为红线

1. 禁止为 `karma-core` 添加 Owner/管理员权限  
2. 禁止将核心费率参数设置为可修改  
3. 测试网阶段严禁长期开启真实扣费与分红  
4. 禁止国库资金绕过治理流程直接转出  

## 风险隔离

经济模块漏洞时：关闭 `enableRevenueMode`，`karma-core` 停止向国库转账即可；核心结算不受影响。
