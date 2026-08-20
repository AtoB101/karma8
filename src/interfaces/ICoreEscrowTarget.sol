// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICoreEscrowTarget
/// @notice Minimal escrow control surface expected by CoreEscrowAdapter.
/// @dev Implemented by ReferenceSettlementCore locally; production karma-core may
///      expose the same selectors or be driven off-chain from adapter events.
interface ICoreEscrowTarget {
    function freezeOrder(bytes32 orderId) external;
    function releaseToSeller(bytes32 orderId) external;
    function refundToBuyer(bytes32 orderId) external;
}
