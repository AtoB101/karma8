// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal surface karma-core is allowed to call on karma-economy.
interface ITreasuryFeeSink {
    function notifyFee(uint256 amount) external;
    function enableRevenueMode() external view returns (bool);
    function feeBps() external view returns (uint256);
}
