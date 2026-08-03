// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {KarmaEconomyConstants} from "../libraries/KarmaEconomyConstants.sol";

/// @title MultiSigWallet
/// @notice 7-owner multisig. Fund ops require >=5/7; controller ops require 7/7.
contract MultiSigWallet {
    enum OpKind {
        Standard, // >=5/7
        Controller // 7/7
    }

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        OpKind kind;
        bool executed;
        uint256 confirmations;
    }

    address[7] public owners;
    mapping(address => bool) public isOwner;
    mapping(uint256 => mapping(address => bool)) public confirmed;
    Transaction[] public transactions;

    event Submit(uint256 indexed txId, address indexed submitter, OpKind kind);
    event Confirm(uint256 indexed txId, address indexed owner);
    event Revoke(uint256 indexed txId, address indexed owner);
    event Execute(uint256 indexed txId);
    event RotateOwner(uint256 indexed seat, address indexed oldOwner, address indexed newOwner);

    error NotOwner();
    error AlreadyConfirmed();
    error NotConfirmed();
    error AlreadyExecuted();
    error ThresholdNotMet();
    error ExecFailed();
    error InvalidOwners();

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner();
        _;
    }

    constructor(address[7] memory owners_) {
        for (uint256 i = 0; i < 7; i++) {
            address o = owners_[i];
            require(o != address(0), "owner=0");
            require(!isOwner[o], "dup owner");
            isOwner[o] = true;
            owners[i] = o;
        }
    }

    receive() external payable {}

    function submitTransaction(address to, uint256 value, bytes calldata data, OpKind kind)
        external
        onlyOwner
        returns (uint256 txId)
    {
        txId = transactions.length;
        transactions.push(
            Transaction({to: to, value: value, data: data, kind: kind, executed: false, confirmations: 0})
        );
        emit Submit(txId, msg.sender, kind);
        confirmTransaction(txId);
    }

    function confirmTransaction(uint256 txId) public onlyOwner {
        Transaction storage t = transactions[txId];
        if (t.executed) revert AlreadyExecuted();
        if (confirmed[txId][msg.sender]) revert AlreadyConfirmed();
        confirmed[txId][msg.sender] = true;
        t.confirmations += 1;
        emit Confirm(txId, msg.sender);
    }

    function revokeConfirmation(uint256 txId) external onlyOwner {
        Transaction storage t = transactions[txId];
        if (t.executed) revert AlreadyExecuted();
        if (!confirmed[txId][msg.sender]) revert NotConfirmed();
        confirmed[txId][msg.sender] = false;
        t.confirmations -= 1;
        emit Revoke(txId, msg.sender);
    }

    function executeTransaction(uint256 txId) external onlyOwner {
        Transaction storage t = transactions[txId];
        if (t.executed) revert AlreadyExecuted();
        uint256 need = t.kind == OpKind.Controller
            ? KarmaEconomyConstants.MULTISIG_CONTROLLER_THRESHOLD
            : KarmaEconomyConstants.MULTISIG_EXEC_THRESHOLD;
        if (t.confirmations < need) revert ThresholdNotMet();
        t.executed = true;
        (bool ok,) = t.to.call{value: t.value}(t.data);
        if (!ok) revert ExecFailed();
        emit Execute(txId);
    }

    /// @notice Annual 1/3 rotation helper: replace one seat via 7/7 controller tx targeting this.
    function rotateOwner(uint256 seat, address newOwner) external {
        require(msg.sender == address(this), "only self");
        require(seat < 7, "seat");
        require(newOwner != address(0) && !isOwner[newOwner], "bad new");
        address old = owners[seat];
        isOwner[old] = false;
        isOwner[newOwner] = true;
        owners[seat] = newOwner;
        emit RotateOwner(seat, old, newOwner);
    }

    function getOwners() external view returns (address[7] memory) {
        return owners;
    }

    function transactionCount() external view returns (uint256) {
        return transactions.length;
    }
}
