// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IKarmaCoreView
/// @notice Read-only surface that karma-economy is allowed to call on karma-core.
/// @dev karma-economy MUST NOT write karma-core state. karma-core may only transfer USDC to Treasury.
interface IKarmaCoreView {
    struct BillSnapshot {
        bytes32 orderId;
        address buyer;
        address seller;
        address developer;
        uint256 amountUsdc;
        uint256 feeUsdc;
        uint64 settledAt;
        bool disputed;
        bool frozen;
    }

    /// @notice Fetch a settled bill snapshot by order id.
    function getBillSnapshot(bytes32 orderId) external view returns (BillSnapshot memory);

    /// @notice Aggregate GMV for a developer over a time window (unix seconds).
    function getDeveloperGmv(address developer, uint64 fromTs, uint64 toTs) external view returns (uint256);

    /// @notice Protocol-wide GMV over a time window.
    function getTotalGmv(uint64 fromTs, uint64 toTs) external view returns (uint256);

    /// @notice Whether an order is currently frozen for dispute.
    function isOrderFrozen(bytes32 orderId) external view returns (bool);
}
