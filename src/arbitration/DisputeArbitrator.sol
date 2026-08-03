// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {KarmaEconomyConstants} from "../libraries/KarmaEconomyConstants.sol";
import {IKarmaCoreView} from "../interfaces/IKarmaCoreView.sol";
import {IMultiTierStake} from "../interfaces/IMultiTierStake.sol";
import {VerifierNodePool} from "../pools/VerifierNodePool.sol";

/// @title DisputeArbitrator
/// @notice Random 15-node panel voting for karma-core order disputes.
/// @dev Economy may only read karma-core snapshots; freeze/release callbacks are optional hooks.
contract DisputeArbitrator is ReentrancyGuard {
    enum Ruling {
        None,
        ReleaseSeller,
        RefundBuyer
    }

    struct Dispute {
        bytes32 orderId;
        address buyer;
        address seller;
        uint256 amountUsdc;
        uint64 openedAt;
        uint64 deadline;
        bool resolved;
        Ruling ruling;
        address[] panel;
        mapping(address => Ruling) votes;
        mapping(address => bool) hasVoted;
        uint256 sellerVotes;
        uint256 buyerVotes;
    }

    IKarmaCoreView public karmaCore;
    IMultiTierStake public immutable stake;
    VerifierNodePool public nodePool;
    address public governance;

    uint256 public nextDisputeId;
    mapping(uint256 => Dispute) private _disputes;
    mapping(bytes32 => uint256) public disputeIdByOrder;
    mapping(address => uint256) public correctRulings;
    mapping(address => uint256) public totalRulings;
    mapping(address => bool) public permanentlyBanned;

    uint256 public slashBps = 1000; // 10% stake slash on malice
    uint256 public constant PANEL_DEADLINE = 3 days;

    /// @notice Optional karma-core freeze/release adapter (must be set by governance if used).
    address public coreEscrowAdapter;

    event DisputeOpened(uint256 indexed disputeId, bytes32 indexed orderId, address[] panel);
    event Voted(uint256 indexed disputeId, address indexed node, Ruling vote);
    event Resolved(uint256 indexed disputeId, Ruling ruling);
    event NodeSlashed(address indexed node, uint256 amount);
    event GovernanceUpdated(address indexed governance);

    error Unauthorized();
    error InvalidState();
    error NotPanel();
    error AlreadyVoted();
    error Banned();

    modifier onlyGovernance() {
        if (msg.sender != governance) revert Unauthorized();
        _;
    }

    constructor(address stake_, address governance_, address karmaCore_) {
        require(stake_ != address(0) && governance_ != address(0), "zero");
        stake = IMultiTierStake(stake_);
        governance = governance_;
        karmaCore = IKarmaCoreView(karmaCore_);
    }

    function setGovernance(address g) external onlyGovernance {
        governance = g;
        emit GovernanceUpdated(g);
    }

    function setKarmaCore(address core) external onlyGovernance {
        karmaCore = IKarmaCoreView(core);
    }

    function setNodePool(address pool) external onlyGovernance {
        nodePool = VerifierNodePool(pool);
    }

    function setCoreEscrowAdapter(address adapter) external onlyGovernance {
        coreEscrowAdapter = adapter;
    }

    function setSlashBps(uint256 bps) external onlyGovernance {
        require(bps <= 5000, "bps");
        slashBps = bps;
    }

    function openDispute(bytes32 orderId) external nonReentrant returns (uint256 id) {
        require(disputeIdByOrder[orderId] == 0, "exists");
        IKarmaCoreView.BillSnapshot memory bill = karmaCore.getBillSnapshot(orderId);
        require(bill.orderId == orderId, "unknown");
        require(bill.disputed || msg.sender == bill.buyer || msg.sender == bill.seller, "auth");

        id = ++nextDisputeId;
        disputeIdByOrder[orderId] = id;
        Dispute storage d = _disputes[id];
        d.orderId = orderId;
        d.buyer = bill.buyer;
        d.seller = bill.seller;
        d.amountUsdc = bill.amountUsdc;
        d.openedAt = uint64(block.timestamp);
        d.deadline = uint64(block.timestamp + PANEL_DEADLINE);
        d.panel = _selectPanel(orderId, id);

        // Best-effort freeze hook
        if (coreEscrowAdapter != address(0)) {
            (bool ok,) = coreEscrowAdapter.call(abi.encodeWithSignature("freezeOrder(bytes32)", orderId));
            ok;
        }

        emit DisputeOpened(id, orderId, d.panel);
    }

    function vote(uint256 disputeId, Ruling choice) external nonReentrant {
        if (permanentlyBanned[msg.sender]) revert Banned();
        Dispute storage d = _disputes[disputeId];
        if (d.resolved || d.openedAt == 0) revert InvalidState();
        if (choice != Ruling.ReleaseSeller && choice != Ruling.RefundBuyer) revert InvalidState();
        if (!_inPanel(d, msg.sender)) revert NotPanel();
        if (d.hasVoted[msg.sender]) revert AlreadyVoted();
        require(stake.isActiveVerifier(msg.sender), "inactive");

        d.hasVoted[msg.sender] = true;
        d.votes[msg.sender] = choice;
        if (choice == Ruling.ReleaseSeller) d.sellerVotes++;
        else d.buyerVotes++;

        emit Voted(disputeId, msg.sender, choice);

        uint256 panelSize = d.panel.length;
        if (d.sellerVotes + d.buyerVotes == panelSize || block.timestamp >= d.deadline) {
            _resolve(disputeId);
        }
    }

    function resolve(uint256 disputeId) external nonReentrant {
        Dispute storage d = _disputes[disputeId];
        if (d.resolved || d.openedAt == 0) revert InvalidState();
        require(
            d.sellerVotes + d.buyerVotes == d.panel.length || block.timestamp >= d.deadline, "early"
        );
        _resolve(disputeId);
    }

    function getPanel(uint256 disputeId) external view returns (address[] memory) {
        return _disputes[disputeId].panel;
    }

    function getDispute(uint256 disputeId)
        external
        view
        returns (
            bytes32 orderId,
            address buyer,
            address seller,
            uint256 amountUsdc,
            bool resolved,
            Ruling ruling,
            uint256 sellerVotes,
            uint256 buyerVotes,
            uint64 deadline
        )
    {
        Dispute storage d = _disputes[disputeId];
        return (
            d.orderId,
            d.buyer,
            d.seller,
            d.amountUsdc,
            d.resolved,
            d.ruling,
            d.sellerVotes,
            d.buyerVotes,
            d.deadline
        );
    }

    function accuracyOf(address node) public view returns (uint256) {
        uint256 total = totalRulings[node];
        if (total == 0) return 0;
        return (correctRulings[node] * 1e18) / total;
    }

    function _resolve(uint256 disputeId) internal {
        Dispute storage d = _disputes[disputeId];
        d.resolved = true;
        Ruling outcome =
            d.sellerVotes >= d.buyerVotes ? Ruling.ReleaseSeller : Ruling.RefundBuyer;
        d.ruling = outcome;

        // Score panel members
        for (uint256 i = 0; i < d.panel.length; i++) {
            address node = d.panel[i];
            if (!d.hasVoted[node]) continue;
            totalRulings[node] += 1;
            if (d.votes[node] == outcome) {
                correctRulings[node] += 1;
            } else {
                // Malicious / consistently wrong: slash if accuracy drops below 40% after >=5 votes
                if (totalRulings[node] >= 5 && accuracyOf(node) < 4e17) {
                    uint256 stakeAmt = stake.stakeOf(node);
                    uint256 slashAmt = (stakeAmt * slashBps) / 10_000;
                    if (slashAmt > 0) {
                        stake.slash(node, slashAmt, true);
                        permanentlyBanned[node] = true;
                        emit NodeSlashed(node, slashAmt);
                    }
                }
            }
            if (address(nodePool) != address(0)) {
                nodePool.setAccuracy(node, accuracyOf(node));
            }
        }

        if (coreEscrowAdapter != address(0)) {
            if (outcome == Ruling.ReleaseSeller) {
                (bool ok,) = coreEscrowAdapter.call(
                    abi.encodeWithSignature("releaseToSeller(bytes32)", d.orderId)
                );
                ok;
            } else {
                (bool ok,) = coreEscrowAdapter.call(abi.encodeWithSignature("refundToBuyer(bytes32)", d.orderId));
                ok;
            }
        }

        emit Resolved(disputeId, outcome);
    }

    function _selectPanel(bytes32 orderId, uint256 disputeId) internal view returns (address[] memory panel) {
        uint256 n = stake.verifierCount();
        uint256 size = KarmaEconomyConstants.ARBITRATOR_PANEL_SIZE;
        if (n < size) size = n;
        require(size > 0, "no verifiers");

        panel = new address[](size);
        // Pseudo-random walk over verifier list; sufficient for testnet panels.
        uint256 seed = uint256(keccak256(abi.encodePacked(orderId, disputeId, block.prevrandao, n)));
        uint256 taken;
        uint256 cursor = seed % n;
        uint256 guard;
        while (taken < size && guard < n * 2) {
            address cand = stake.verifierAt(cursor % n);
            if (stake.isActiveVerifier(cand) && !permanentlyBanned[cand] && !_contains(panel, taken, cand)) {
                panel[taken] = cand;
                taken++;
            }
            cursor++;
            guard++;
        }
        require(taken == size, "panel");
        // shrink if needed — size already exact
    }

    function _contains(address[] memory arr, uint256 len, address a) internal pure returns (bool) {
        for (uint256 i = 0; i < len; i++) {
            if (arr[i] == a) return true;
        }
        return false;
    }

    function _inPanel(Dispute storage d, address a) internal view returns (bool) {
        for (uint256 i = 0; i < d.panel.length; i++) {
            if (d.panel[i] == a) return true;
        }
        return false;
    }
}