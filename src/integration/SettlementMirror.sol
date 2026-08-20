// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IKarmaCoreView} from "../interfaces/IKarmaCoreView.sol";

/// @title SettlementMirror
/// @notice Read model for karma-economy. karma-core (or a trusted reporter) pushes
///         bill snapshots / GMV; economy never writes into karma-core.
contract SettlementMirror is IKarmaCoreView {
    address public governance;
    mapping(address => bool) public isReporter;

    mapping(bytes32 => BillSnapshot) internal _bills;
    mapping(address => uint256) public lifetimeDeveloperGmv;
    uint256 public lifetimeTotalGmv;
    mapping(bytes32 => bool) public frozen;

    // Rolling window buckets (day id => amount) for simple range queries
    mapping(address => mapping(uint64 => uint256)) public developerGmvByDay;
    mapping(uint64 => uint256) public totalGmvByDay;

    event ReporterUpdated(address indexed reporter, bool enabled);
    event GovernanceUpdated(address indexed governance);
    event BillRecorded(bytes32 indexed orderId, address indexed developer, uint256 amountUsdc, uint256 feeUsdc);
    event FreezeUpdated(bytes32 indexed orderId, bool frozen);

    error Unauthorized();

    modifier onlyReporter() {
        if (!isReporter[msg.sender]) revert Unauthorized();
        _;
    }

    modifier onlyGovernance() {
        if (msg.sender != governance) revert Unauthorized();
        _;
    }

    constructor(address governance_, address reporter_) {
        require(governance_ != address(0), "zero");
        governance = governance_;
        if (reporter_ != address(0)) {
            isReporter[reporter_] = true;
            emit ReporterUpdated(reporter_, true);
        }
    }

    function setReporter(address reporter_, bool enabled) external onlyGovernance {
        isReporter[reporter_] = enabled;
        emit ReporterUpdated(reporter_, enabled);
    }

    function setGovernance(address governance_) external onlyGovernance {
        require(governance_ != address(0), "zero");
        governance = governance_;
        emit GovernanceUpdated(governance_);
    }

    /// @notice Called by karma-core bridge after a successful settle (+ optional fee).
    /// @dev Self-deal (buyer==seller) still records the bill but does NOT credit developer GMV.
    function recordBill(BillSnapshot calldata bill) external onlyReporter {
        require(bill.orderId != bytes32(0), "order");
        _bills[bill.orderId] = bill;

        bool creditGmv = bill.amountUsdc > 0 && bill.developer != address(0) && bill.buyer != bill.seller;
        if (creditGmv) {
            uint64 day = uint64(bill.settledAt / 1 days);
            lifetimeDeveloperGmv[bill.developer] += bill.amountUsdc;
            lifetimeTotalGmv += bill.amountUsdc;
            developerGmvByDay[bill.developer][day] += bill.amountUsdc;
            totalGmvByDay[day] += bill.amountUsdc;
        }

        emit BillRecorded(bill.orderId, bill.developer, bill.amountUsdc, bill.feeUsdc);
    }

    function setFrozen(bytes32 orderId, bool isFrozen) external onlyReporter {
        frozen[orderId] = isFrozen;
        BillSnapshot storage b = _bills[orderId];
        if (b.orderId != bytes32(0)) b.frozen = isFrozen;
        emit FreezeUpdated(orderId, isFrozen);
    }

    function getBillSnapshot(bytes32 orderId) external view returns (BillSnapshot memory) {
        return _bills[orderId];
    }

    function getDeveloperGmv(address developer, uint64 fromTs, uint64 toTs) external view returns (uint256 total) {
        if (toTs <= fromTs) return 0;
        uint64 startDay = fromTs / 1 days;
        uint64 endDay = (toTs - 1) / 1 days;
        for (uint64 d = startDay; d <= endDay; d++) {
            total += developerGmvByDay[developer][d];
        }
    }

    function getTotalGmv(uint64 fromTs, uint64 toTs) external view returns (uint256 total) {
        if (toTs <= fromTs) return 0;
        uint64 startDay = fromTs / 1 days;
        uint64 endDay = (toTs - 1) / 1 days;
        for (uint64 d = startDay; d <= endDay; d++) {
            total += totalGmvByDay[d];
        }
    }

    function isOrderFrozen(bytes32 orderId) external view returns (bool) {
        return frozen[orderId] || _bills[orderId].frozen;
    }
}
