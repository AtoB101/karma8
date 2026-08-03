# karma-core 最小对接补丁（AtoB101/Karma）

按经济规格：**karma-core 仅新增国库相关对接，不新增 Owner 权限体系**（沿用现有 `admin` 做一次性配置）。

目标仓库：`https://github.com/AtoB101/Karma`  
目标合约：`karma-core/contracts/core/KarmaBilateral.sol`

## 1. 新增状态

```solidity
address public treasury; // karma-economy Treasury
address public feeBridge; // karma-economy FeeBridge (recommended)
uint256 public constant PROTOCOL_FEE_BPS = 20; // immutable 0.2%; DO NOT add setter
```

```solidity
function setTreasury(address treasury_) external onlyAdmin {
    treasury = treasury_;
}

function setFeeBridge(address feeBridge_) external onlyAdmin {
    feeBridge = feeBridge_;
}
```

> 不新增独立 Owner；仅复用已有 `admin`。部署后可将 admin 移交多签/销毁配置权。

## 2. 在 `_executeSettle` 释放 USDC 前抽费

伪代码（从 agent/seller 侧成交额计费，或按业务改为成交总额）：

```solidity
uint256 total = buyerBill.amount + agentBill.amount;
uint256 fee;
if (treasury != address(0) && feeBridge != address(0)) {
    // Prefer economy quote (0 while revenue mode off / partner tier etc.)
    (bool ok, bytes memory ret) = feeBridge.staticcall(
        abi.encodeWithSignature("quoteFee(address,uint256)", agentBill.owner, total)
    );
    if (ok && ret.length >= 32) fee = abi.decode(ret, (uint256));
}

if (fee > 0) {
    // reduce agent payout by fee (example policy)
    // transfer fee to FeeBridge via approve+collectAndRecord OR transfer to Treasury + notifyFee
    IERC20Min(token).approve(feeBridge, fee);
    (bool cOk,) = feeBridge.call(
        abi.encodeWithSignature(
            "collectAndRecord(bytes32,address,address,address,uint256,uint256)",
            bytes32(bindingId),
            buyerBill.owner,
            agentBill.owner,
            agentBill.owner,
            total,
            fee
        )
    );
    require(cOk, "fee bridge");
}
// then existing _transfer payouts with fee deducted from agent side
```

## 3. 只读视图

economy 不直接依赖 Bilateral 内部结构；通过 `FeeBridge` → `SettlementMirror.recordBill` 建立 GMV/账单快照。  
`DisputeArbitrator` 读取 `SettlementMirror`（`IKarmaCoreView`）。

## 4. 验收

1. `treasury=0` 或 revenue off：结算 0 手续费（免费冷启动）  
2. revenue on：0.2%（开发者质押达标 0.1%，合伙人 0）  
3. Bilateral 不持有 economy 写权限，除 `FeeBridge.collectAndRecord`  
4. 不出现可修改 `PROTOCOL_FEE_BPS` 的 setter  

本仓库提供本地替代实现：`ReferenceSettlementCore` + `FeeBridge` + `SettlementMirror`，可用 `forge test --match-contract FlywheelE2E` 验证飞轮。
