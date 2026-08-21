// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {KarmaEconomyConstants} from "../libraries/KarmaEconomyConstants.sol";
import {IMultiTierStake} from "../interfaces/IMultiTierStake.sol";
import {Treasury} from "../treasury/Treasury.sol";

/// @title KarmaGovernor
/// @notice Stake-weighted governance. Fee bps and split ratios are non-governable.
contract KarmaGovernor is ReentrancyGuard {
    enum ProposalType {
        EnableRevenueMode,
        DisableRevenueMode,
        EcoSubsidy,
        NodeSlashBps,
        CustomCall
    }

    struct Proposal {
        ProposalType pType;
        address proposer;
        uint64 start;
        uint64 end;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bool canceled;
        // EcoSubsidy payload
        Treasury.SubsidyKind subsidyKind;
        uint256 subsidyAmount;
        // Custom call payload
        address target;
        bytes data;
        string description;
    }

    IMultiTierStake public immutable stake;
    Treasury public treasury;
    address public guardian; // multisig for cancel / bootstrap

    uint256 public nextProposalId;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(uint256 indexed id, ProposalType pType, address indexed proposer);
    event Voted(uint256 indexed id, address indexed voter, bool support, uint256 weight);
    event Executed(uint256 indexed id);
    event Canceled(uint256 indexed id);

    error Unauthorized();
    error InvalidProposal();
    error NotActive();
    error AlreadyVoted();
    error NotSucceeded();
    error ForbiddenParam();

    modifier onlyGuardian() {
        if (msg.sender != guardian) revert Unauthorized();
        _;
    }

    constructor(address stake_, address treasury_, address guardian_) {
        require(stake_ != address(0) && treasury_ != address(0) && guardian_ != address(0), "zero");
        stake = IMultiTierStake(stake_);
        treasury = Treasury(treasury_);
        guardian = guardian_;
    }

    function setTreasury(address t) external onlyGuardian {
        treasury = Treasury(t);
    }

    function setGuardian(address g) external onlyGuardian {
        require(g != address(0), "zero");
        guardian = g;
    }

    function proposeEnableRevenue(bool enable, string calldata description) external returns (uint256 id) {
        id = _create(
            enable ? ProposalType.EnableRevenueMode : ProposalType.DisableRevenueMode,
            Treasury.SubsidyKind.GovernanceEcoSubsidy,
            0,
            address(0),
            "",
            description
        );
    }

    function proposeEcoSubsidy(Treasury.SubsidyKind kind, uint256 amount, string calldata description)
        external
        returns (uint256 id)
    {
        require(amount > 0, "amount");
        id = _create(ProposalType.EcoSubsidy, kind, amount, address(0), "", description);
    }

    function proposeCustomCall(address target, bytes calldata data, string calldata description)
        external
        returns (uint256 id)
    {
        // Deny dangerous privilege escalations / fee-adjacent admin.
        bytes4 sel;
        if (data.length >= 4) {
            sel = bytes4(data[0:4]);
        }
        if (
            sel == bytes4(keccak256("setFeeBps(uint256)"))
                || sel == bytes4(keccak256("setSplitRatios(uint256,uint256,uint256,uint256)"))
                || sel == bytes4(keccak256("setGovernance(address)")) || sel == bytes4(keccak256("setCore(address)"))
                || sel == bytes4(keccak256("setReporter(address,bool)"))
                || sel == bytes4(keccak256("setEnableRevenueMode(bool)"))
                || sel == bytes4(keccak256("setRevenueMode(bool)"))
                || sel == bytes4(keccak256("slash(address,uint256,bool)"))
                || sel == bytes4(keccak256("setTreasury(address)"))
        ) {
            revert ForbiddenParam();
        }
        id = _create(ProposalType.CustomCall, Treasury.SubsidyKind.GovernanceEcoSubsidy, 0, target, data, description);
    }

    function vote(uint256 id, bool support) external {
        Proposal storage p = proposals[id];
        if (p.executed || p.canceled) revert NotActive();
        if (block.timestamp < p.start || block.timestamp > p.end) revert NotActive();
        if (hasVoted[id][msg.sender]) revert AlreadyVoted();

        uint256 weight = stake.votingWeight(msg.sender);
        require(weight > 0, "weight");
        hasVoted[id][msg.sender] = true;
        if (support) p.forVotes += weight;
        else p.againstVotes += weight;
        emit Voted(id, msg.sender, support, weight);
    }

    function execute(uint256 id) external nonReentrant {
        Proposal storage p = proposals[id];
        if (p.executed || p.canceled) revert InvalidProposal();
        if (block.timestamp <= p.end) revert NotActive();

        if (!_succeeded(p)) revert NotSucceeded();

        p.executed = true;

        if (p.pType == ProposalType.EnableRevenueMode) {
            treasury.setEnableRevenueMode(true);
            // propagate staking fee discounts
            (bool ok,) = address(stake).call(abi.encodeWithSignature("setRevenueMode(bool)", true));
            ok;
        } else if (p.pType == ProposalType.DisableRevenueMode) {
            treasury.setEnableRevenueMode(false);
            (bool ok,) = address(stake).call(abi.encodeWithSignature("setRevenueMode(bool)", false));
            ok;
        } else if (p.pType == ProposalType.EcoSubsidy) {
            treasury.executeSubsidy(p.subsidyKind, p.subsidyAmount, bytes32(id));
        } else if (p.pType == ProposalType.CustomCall) {
            (bool ok, bytes memory ret) = p.target.call(p.data);
            require(ok, string(ret));
        }

        emit Executed(id);
    }

    function cancel(uint256 id) external onlyGuardian {
        Proposal storage p = proposals[id];
        require(!p.executed, "executed");
        p.canceled = true;
        emit Canceled(id);
    }

    function state(uint256 id)
        external
        view
        returns (bool active, bool succeeded, bool executed, uint256 forVotes, uint256 againstVotes)
    {
        Proposal storage p = proposals[id];
        executed = p.executed;
        forVotes = p.forVotes;
        againstVotes = p.againstVotes;
        active = !p.executed && !p.canceled && block.timestamp >= p.start && block.timestamp <= p.end;
        succeeded = _succeeded(p);
    }

    function _succeeded(Proposal storage p) internal view returns (bool) {
        uint256 cast = p.forVotes + p.againstVotes;
        if (cast == 0) return false;
        uint256 supply = stake.totalVotingWeight();
        if (supply == 0) return false;
        if ((cast * 10_000) / supply < KarmaEconomyConstants.QUORUM_PARTICIPATION_BPS) return false;
        return (p.forVotes * 10_000) / cast >= KarmaEconomyConstants.QUORUM_BPS;
    }

    function _create(
        ProposalType pType,
        Treasury.SubsidyKind kind,
        uint256 amount,
        address target,
        bytes memory data,
        string calldata description
    ) internal returns (uint256 id) {
        require(stake.votingWeight(msg.sender) > 0, "stake");
        id = ++nextProposalId;
        Proposal storage p = proposals[id];
        p.pType = pType;
        p.proposer = msg.sender;
        p.start = uint64(block.timestamp);
        p.end = uint64(block.timestamp + KarmaEconomyConstants.VOTING_PERIOD);
        p.subsidyKind = kind;
        p.subsidyAmount = amount;
        p.target = target;
        p.data = data;
        p.description = description;
        emit ProposalCreated(id, pType, msg.sender);
    }
}
