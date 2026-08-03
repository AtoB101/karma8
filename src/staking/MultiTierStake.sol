// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {KarmaEconomyConstants} from "../libraries/KarmaEconomyConstants.sol";
import {IMultiTierStake} from "../interfaces/IMultiTierStake.sol";

/// @title MultiTierStake
/// @notice Four-tier KARMA staking with duration-weighted voting power.
contract MultiTierStake is IMultiTierStake, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Position {
        uint256 amount;
        uint64 startedAt;
        uint64 unlockAt;
        Tier tier;
        bool banned;
    }

    IERC20 public immutable karma;
    address public governance;
    address public arbitrator;
    bool public revenueMode; // mirrors Treasury; fee discounts / USDC dividends gated

    mapping(address => Position) public positions;
    mapping(address => uint256) public weightCheckpoint; // last accounted voting weight
    address[] internal _verifiers;
    mapping(address => uint256) internal _verifierIndex; // 1-based
    uint256 public totalStaked;
    uint256 public totalVotingWeight;

    event Staked(address indexed user, uint256 amount, Tier tier);
    event Unstaked(address indexed user, uint256 amount);
    event Slashed(address indexed user, uint256 amount, bool permanentBan);
    event RevenueModeUpdated(bool enabled);
    event GovernanceUpdated(address indexed governance);
    event ArbitratorUpdated(address indexed arbitrator);

    error Unauthorized();
    error Banned();
    error InsufficientTier();
    error Locked();
    error ZeroAmount();

    modifier onlyGovernance() {
        if (msg.sender != governance) revert Unauthorized();
        _;
    }

    constructor(address karma_, address governance_) {
        require(karma_ != address(0) && governance_ != address(0), "zero");
        karma = IERC20(karma_);
        governance = governance_;
    }

    function setGovernance(address g) external onlyGovernance {
        require(g != address(0), "zero");
        governance = g;
        emit GovernanceUpdated(g);
    }

    function setArbitrator(address a) external onlyGovernance {
        arbitrator = a;
        emit ArbitratorUpdated(a);
    }

    function setRevenueMode(bool enabled) external onlyGovernance {
        revenueMode = enabled;
        emit RevenueModeUpdated(enabled);
    }

    function stake(uint256 amount, Tier tier) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Position storage p = positions[msg.sender];
        if (p.banned) revert Banned();

        // Duration resets on additional stake
        uint256 newAmount = p.amount + amount;
        Tier effective = _resolveTier(newAmount, tier, p.tier);
        if (!_meetsMin(effective, newAmount)) revert InsufficientTier();

        _clearWeight(msg.sender);

        karma.safeTransferFrom(msg.sender, address(this), amount);

        p.amount = newAmount;
        p.startedAt = uint64(block.timestamp);
        p.tier = effective;
        p.unlockAt = _unlockAt(effective, p.startedAt);

        totalStaked += amount;
        _setWeight(msg.sender);

        _syncVerifier(msg.sender, effective);
        emit Staked(msg.sender, amount, effective);
    }

    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Position storage p = positions[msg.sender];
        if (p.banned) revert Banned();
        require(amount <= p.amount, "exceeds");
        if (block.timestamp < p.unlockAt) revert Locked();

        _clearWeight(msg.sender);

        p.amount -= amount;
        totalStaked -= amount;

        if (p.amount == 0) {
            // Full unstake resets duration accounting
            p.startedAt = 0;
            p.unlockAt = 0;
            p.tier = Tier.None;
            _syncVerifier(msg.sender, Tier.None);
        } else {
            // Partial unstake: recompute tier floor, duration continues (spec: reset only on add or full exit)
            p.tier = _floorTier(p.amount, p.tier);
            p.unlockAt = _unlockAt(p.tier, p.startedAt);
            _setWeight(msg.sender);
            _syncVerifier(msg.sender, p.tier);
        }

        karma.safeTransfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    function slash(address account, uint256 amount, bool permanentBan) external override {
        if (msg.sender != arbitrator && msg.sender != governance) revert Unauthorized();
        Position storage p = positions[account];
        require(p.amount > 0, "no stake");
        if (amount > p.amount) amount = p.amount;

        _clearWeight(account);
        p.amount -= amount;
        totalStaked -= amount;

        if (permanentBan) {
            p.banned = true;
            p.tier = Tier.None;
            p.startedAt = 0;
            p.unlockAt = 0;
            _syncVerifier(account, Tier.None);
        } else if (p.amount == 0) {
            p.tier = Tier.None;
            p.startedAt = 0;
            p.unlockAt = 0;
            _syncVerifier(account, Tier.None);
        } else {
            p.tier = _floorTier(p.amount, p.tier);
            _setWeight(account);
            _syncVerifier(account, p.tier);
        }

        // Slashed tokens burned
        karma.safeTransfer(KarmaEconomyConstants.BURN_ADDRESS, amount);
        emit Slashed(account, amount, permanentBan);
    }

    function stakeOf(address account) external view returns (uint256) {
        return positions[account].amount;
    }

    function tierOf(address account) external view returns (Tier) {
        return positions[account].tier;
    }

    function durationMultiplier(address account) public view returns (uint256) {
        Position memory p = positions[account];
        if (p.amount == 0 || p.startedAt == 0) return 0;
        uint256 held = block.timestamp - p.startedAt;
        if (held >= KarmaEconomyConstants.DURATION_12M) return KarmaEconomyConstants.MULT_12M;
        if (held >= KarmaEconomyConstants.DURATION_3M) return KarmaEconomyConstants.MULT_3M;
        return KarmaEconomyConstants.MULT_BASE;
    }

    function votingWeight(address account) public view returns (uint256) {
        Position memory p = positions[account];
        if (p.amount == 0) return 0;
        return (p.amount * durationMultiplier(account)) / KarmaEconomyConstants.MULT_BASE;
    }

    /// @notice Refresh checkpoint so duration growth is reflected in totalVotingWeight.
    function syncWeight(address account) external {
        _clearWeight(account);
        _setWeight(account);
    }

    function _clearWeight(address account) internal {
        uint256 cached = weightCheckpoint[account];
        if (cached > 0) {
            totalVotingWeight -= cached;
            weightCheckpoint[account] = 0;
        }
    }

    function _setWeight(address account) internal {
        uint256 w = votingWeight(account);
        weightCheckpoint[account] = w;
        totalVotingWeight += w;
    }

    function isActiveVerifier(address account) public view returns (bool) {
        Position memory p = positions[account];
        return !p.banned && p.tier == Tier.Verifier && p.amount >= KarmaEconomyConstants.TIER3_MIN;
    }

    function isDeveloper(address account) external view returns (bool) {
        Position memory p = positions[account];
        return !p.banned && uint8(p.tier) >= uint8(Tier.Developer) && p.amount >= KarmaEconomyConstants.TIER2_MIN;
    }

    function isPartner(address account) external view returns (bool) {
        Position memory p = positions[account];
        return !p.banned && p.tier == Tier.Partner && p.amount >= KarmaEconomyConstants.TIER4_MIN;
    }

    /// @notice Effective fee bps for an agent owner. Partners=0, Developers=10 (if revenue), else 20.
    /// @dev Returns full fee when revenueMode is false (testnet free mode still reports base for reads;
    ///      karma-core should gate charging separately). When revenueMode false, returns 0 to keep free.
    function feeBpsFor(address account) external view returns (uint256) {
        if (!revenueMode) return 0;
        Position memory p = positions[account];
        if (p.banned) return KarmaEconomyConstants.FEE_BPS;
        if (p.tier == Tier.Partner && p.amount >= KarmaEconomyConstants.TIER4_MIN) return 0;
        if (uint8(p.tier) >= uint8(Tier.Developer) && p.amount >= KarmaEconomyConstants.TIER2_MIN) {
            return KarmaEconomyConstants.DEVELOPER_FEE_BPS;
        }
        return KarmaEconomyConstants.FEE_BPS;
    }

    function verifierCount() external view returns (uint256) {
        return _verifiers.length;
    }

    function verifierAt(uint256 index) external view returns (address) {
        return _verifiers[index];
    }

    function _meetsMin(Tier tier, uint256 amount) internal pure returns (bool) {
        if (tier == Tier.Public || tier == Tier.None) return amount > 0 || tier == Tier.None;
        if (tier == Tier.Developer) return amount >= KarmaEconomyConstants.TIER2_MIN;
        if (tier == Tier.Verifier) return amount >= KarmaEconomyConstants.TIER3_MIN;
        if (tier == Tier.Partner) return amount >= KarmaEconomyConstants.TIER4_MIN;
        return false;
    }

    function _unlockAt(Tier tier, uint64 started) internal pure returns (uint64) {
        if (tier == Tier.Developer) return started + uint64(KarmaEconomyConstants.TIER2_LOCK);
        if (tier == Tier.Verifier) return started + uint64(KarmaEconomyConstants.TIER3_LOCK);
        // Partner lock unspecified in spec ("-"): no forced lock period
        return 0;
    }

    function _resolveTier(uint256 amount, Tier requested, Tier current) internal pure returns (Tier) {
        Tier t = requested;
        if (uint8(current) > uint8(t)) t = current;
        // Cap by amount
        if (amount >= KarmaEconomyConstants.TIER4_MIN && uint8(t) > uint8(Tier.Partner)) {
            // no-op
        }
        if (!_meetsMin(t, amount)) {
            // downgrade to highest affordable
            return _floorTier(amount, t);
        }
        return t;
    }

    function _floorTier(uint256 amount, Tier hint) internal pure returns (Tier) {
        if (amount >= KarmaEconomyConstants.TIER4_MIN && uint8(hint) >= uint8(Tier.Partner)) {
            return Tier.Partner;
        }
        if (amount >= KarmaEconomyConstants.TIER3_MIN && uint8(hint) >= uint8(Tier.Verifier)) {
            return Tier.Verifier;
        }
        if (amount >= KarmaEconomyConstants.TIER2_MIN && uint8(hint) >= uint8(Tier.Developer)) {
            return Tier.Developer;
        }
        if (amount > 0) return Tier.Public;
        return Tier.None;
    }

    function _syncVerifier(address account, Tier tier) internal {
        bool should = tier == Tier.Verifier || tier == Tier.Partner;
        uint256 idx = _verifierIndex[account];
        if (should && idx == 0) {
            _verifiers.push(account);
            _verifierIndex[account] = _verifiers.length;
        } else if (!should && idx != 0) {
            uint256 i = idx - 1;
            address last = _verifiers[_verifiers.length - 1];
            _verifiers[i] = last;
            _verifierIndex[last] = i + 1;
            _verifiers.pop();
            _verifierIndex[account] = 0;
        }
    }
}
