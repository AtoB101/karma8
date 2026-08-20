// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SettlementMirror} from "./SettlementMirror.sol";
import {ICoreEscrowTarget} from "../interfaces/ICoreEscrowTarget.sol";

/// @title CoreEscrowAdapter
/// @notice Freeze/release hooks used by DisputeArbitrator.
/// @dev Updates SettlementMirror freeze flags, optionally forwards to a karma-core
///      escrow target (ReferenceSettlementCore or a Bilateral-compatible wrapper),
///      and always emits actionable events for off-chain/core executors.
contract CoreEscrowAdapter {
    SettlementMirror public immutable mirror;
    address public arbitrator;
    address public governance;
    ICoreEscrowTarget public coreTarget;

    event FreezeOrder(bytes32 indexed orderId);
    event ReleaseToSeller(bytes32 indexed orderId);
    event RefundToBuyer(bytes32 indexed orderId);
    event CoreTargetUpdated(address indexed coreTarget);
    event GovernanceUpdated(address indexed governance);
    event ArbitratorUpdated(address indexed arbitrator);

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
        emit ArbitratorUpdated(a);
    }

    function setGovernance(address g) external onlyGovernance {
        require(g != address(0), "zero");
        governance = g;
        emit GovernanceUpdated(g);
    }

    function setCoreTarget(address target) external onlyGovernance {
        coreTarget = ICoreEscrowTarget(target);
        emit CoreTargetUpdated(target);
    }

    function freezeOrder(bytes32 orderId) external onlyArbitrator {
        try mirror.setFrozen(orderId, true) {} catch {}
        if (address(coreTarget) != address(0)) {
            try coreTarget.freezeOrder(orderId) {} catch {}
        }
        emit FreezeOrder(orderId);
    }

    function releaseToSeller(bytes32 orderId) external onlyArbitrator {
        try mirror.setFrozen(orderId, false) {} catch {}
        if (address(coreTarget) != address(0)) {
            try coreTarget.releaseToSeller(orderId) {} catch {}
        }
        emit ReleaseToSeller(orderId);
    }

    function refundToBuyer(bytes32 orderId) external onlyArbitrator {
        try mirror.setFrozen(orderId, false) {} catch {}
        if (address(coreTarget) != address(0)) {
            try coreTarget.refundToBuyer(orderId) {} catch {}
        }
        emit RefundToBuyer(orderId);
    }
}
