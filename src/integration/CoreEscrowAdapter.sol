// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SettlementMirror} from "./SettlementMirror.sol";

/// @title CoreEscrowAdapter
/// @notice Best-effort freeze/release hooks used by DisputeArbitrator.
/// @dev In production this should forward to karma-core escrow controls.
///      Here it updates SettlementMirror freeze flags and emits actionable events
///      for an off-chain/core executor.
contract CoreEscrowAdapter {
    SettlementMirror public immutable mirror;
    address public arbitrator;
    address public governance;

    event FreezeOrder(bytes32 indexed orderId);
    event ReleaseToSeller(bytes32 indexed orderId);
    event RefundToBuyer(bytes32 indexed orderId);

    error Unauthorized();

    modifier onlyArbitrator() {
        if (msg.sender != arbitrator) revert Unauthorized();
        _;
    }

    modifier onlyGovernance() {
        if (msg.sender != governance) revert Unauthorized();
        _;
    }

    constructor(address mirror_, address governance_) {
        require(mirror_ != address(0) && governance_ != address(0), "zero");
        mirror = SettlementMirror(mirror_);
        governance = governance_;
    }

    function setArbitrator(address a) external onlyGovernance {
        arbitrator = a;
    }

    function freezeOrder(bytes32 orderId) external onlyArbitrator {
        // Reporter role on mirror must be this adapter or a shared bridge — governance sets reporter.
        // If adapter is not reporter, only emit for off-chain execution.
        try mirror.setFrozen(orderId, true) {} catch {}
        emit FreezeOrder(orderId);
    }

    function releaseToSeller(bytes32 orderId) external onlyArbitrator {
        try mirror.setFrozen(orderId, false) {} catch {}
        emit ReleaseToSeller(orderId);
    }

    function refundToBuyer(bytes32 orderId) external onlyArbitrator {
        try mirror.setFrozen(orderId, false) {} catch {}
        emit RefundToBuyer(orderId);
    }
}
