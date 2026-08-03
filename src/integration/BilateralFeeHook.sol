// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FeeBridge} from "./FeeBridge.sol";

/// @title BilateralFeeHook
/// @notice Drop-in helper for karma-core KarmaBilateral._executeSettle.
/// @dev karma-core should call this instead of hand-rolling fee math.
library BilateralFeeHook {
    using SafeERC20 for IERC20;

    /// @notice Quote + optionally pull fee from `payer` (typically the bilateral contract itself)
    ///         and record settlement into economy FeeBridge/SettlementMirror.
    /// @return feeUsdc Fee charged (0 when revenue mode off / partner tier / bridge unset).
    function collectOnSettle(
        address feeBridge,
        address usdc,
        bytes32 orderId,
        address buyer,
        address seller,
        address developer,
        uint256 amountUsdc
    ) internal returns (uint256 feeUsdc) {
        if (feeBridge == address(0) || amountUsdc == 0) {
            return 0;
        }
        FeeBridge bridge = FeeBridge(feeBridge);
        feeUsdc = bridge.quoteFee(developer, amountUsdc);
        if (feeUsdc == 0) {
            // Still mirror GMV during cold-start free mode.
            // Caller must be authorized as bridge.core.
            bridge.collectAndRecord(orderId, buyer, seller, developer, amountUsdc, 0);
            return 0;
        }
        IERC20(usdc).forceApprove(feeBridge, feeUsdc);
        bridge.collectAndRecord(orderId, buyer, seller, developer, amountUsdc, feeUsdc);
    }
}
