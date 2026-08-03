// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {KarmaEconomyConstants} from "../libraries/KarmaEconomyConstants.sol";
import {IMultiTierStake} from "../interfaces/IMultiTierStake.sol";

/// @title KarmaVesting
/// @notice Token allocation vesting with category-specific unlock rules.
contract KarmaVesting is ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum Category {
        Team, // 15%: 1y cliff, 24m linear; unlock requires 500k stake as verifier node
        Investor, // 12%: 6m cliff, 18m linear; 7-day stake hold before claim
        Ecosystem, // 28%: 48m linear via distributor
        Mining, // 25%: 4y halving monthly release via distributor
        Tge, // 15%: 8% liquid at TGE, 7% over 12 months
        TreasuryReserve // 5%: locked 2y, governance only
    }

    struct Grant {
        Category category;
        address beneficiary;
        uint256 total;
        uint256 claimed;
        uint64 start;
        bool active;
    }

    IERC20 public immutable karma;
    IMultiTierStake public stake;
    address public governance;
    address public distributor;

    uint256 public nextGrantId;
    mapping(uint256 => Grant) public grants;
    mapping(address => uint256[]) public grantsOf;

    // Investor post-unlock stake hold tracking
    mapping(address => uint64) public investorStakeReadyAt;

    event GrantCreated(uint256 indexed id, Category category, address indexed beneficiary, uint256 total);
    event Claimed(uint256 indexed id, address indexed beneficiary, uint256 amount);
    event GovernanceUpdated(address indexed governance);
    event StakeUpdated(address indexed stake);
    event DistributorUpdated(address indexed distributor);

    error Unauthorized();
    error Inactive();
    error NothingToClaim();
    error TeamStakeRequired();
    error InvestorHold();

    modifier onlyGovernance() {
        if (msg.sender != governance) revert Unauthorized();
        _;
    }

    constructor(address karma_, address governance_) {
        require(karma_ != address(0) && governance_ != address(0), "zero");
        karma = IERC20(karma_);
        governance = governance_;
    }

    function setStake(address stake_) external onlyGovernance {
        stake = IMultiTierStake(stake_);
        emit StakeUpdated(stake_);
    }

    function setDistributor(address distributor_) external onlyGovernance {
        distributor = distributor_;
        emit DistributorUpdated(distributor_);
    }

    function setGovernance(address governance_) external onlyGovernance {
        require(governance_ != address(0), "zero");
        governance = governance_;
        emit GovernanceUpdated(governance_);
    }

    function createGrant(Category category, address beneficiary, uint256 total, uint64 start)
        external
        onlyGovernance
        returns (uint256 id)
    {
        require(beneficiary != address(0) && total > 0, "bad grant");
        id = ++nextGrantId;
        grants[id] = Grant({
            category: category,
            beneficiary: beneficiary,
            total: total,
            claimed: 0,
            start: start,
            active: true
        });
        grantsOf[beneficiary].push(id);
        emit GrantCreated(id, category, beneficiary, total);
    }

    function vestedAmount(uint256 id) public view returns (uint256) {
        Grant memory g = grants[id];
        if (!g.active) return 0;
        uint256 t = block.timestamp;
        if (t < g.start) return 0;

        if (g.category == Category.Team) {
            // 1y cliff, then 24m linear
            uint256 cliff = g.start + 365 days;
            if (t < cliff) return 0;
            uint256 duration = 730 days;
            uint256 elapsed = t - cliff;
            if (elapsed >= duration) return g.total;
            return (g.total * elapsed) / duration;
        }
        if (g.category == Category.Investor) {
            uint256 cliff = g.start + 180 days;
            if (t < cliff) return 0;
            uint256 duration = 540 days;
            uint256 elapsed = t - cliff;
            if (elapsed >= duration) return g.total;
            return (g.total * elapsed) / duration;
        }
        if (g.category == Category.Ecosystem) {
            uint256 duration = 1460 days; // 48 months
            uint256 elapsed = t - g.start;
            if (elapsed >= duration) return g.total;
            return (g.total * elapsed) / duration;
        }
        if (g.category == Category.Mining) {
            // Approx 4y monthly halving schedule as linear-with-halving epochs of 1y
            return _miningVested(g.total, g.start, t);
        }
        if (g.category == Category.Tge) {
            // 8/15 liquid at start, remaining 7/15 over 12 months
            uint256 immediate = (g.total * 8) / 15;
            uint256 locked = g.total - immediate;
            uint256 duration = 365 days;
            uint256 elapsed = t - g.start;
            if (elapsed >= duration) return g.total;
            return immediate + (locked * elapsed) / duration;
        }
        // TreasuryReserve: locked 2 years, then fully available to governance beneficiary
        if (t < g.start + 730 days) return 0;
        return g.total;
    }

    function claimable(uint256 id) public view returns (uint256) {
        Grant memory g = grants[id];
        uint256 vested = vestedAmount(id);
        if (vested <= g.claimed) return 0;
        return vested - g.claimed;
    }

    function claim(uint256 id) external nonReentrant {
        Grant storage g = grants[id];
        if (!g.active) revert Inactive();
        require(msg.sender == g.beneficiary || msg.sender == governance, "not beneficiary");

        uint256 amount = claimable(id);
        if (amount == 0) revert NothingToClaim();

        if (g.category == Category.Team) {
            // Must stake >= 500k and be active verifier node to unlock
            if (address(stake) == address(0) || stake.stakeOf(g.beneficiary) < KarmaEconomyConstants.TIER3_MIN) {
                revert TeamStakeRequired();
            }
            if (!stake.isActiveVerifier(g.beneficiary)) revert TeamStakeRequired();
        }

        if (g.category == Category.Investor) {
            // After unlock, must stake 7 days before extract
            uint64 ready = investorStakeReadyAt[g.beneficiary];
            if (ready == 0 || block.timestamp < ready) revert InvestorHold();
        }

        if (g.category == Category.TreasuryReserve) {
            require(msg.sender == governance, "gov only");
        }

        g.claimed += amount;
        karma.safeTransfer(g.beneficiary, amount);
        emit Claimed(id, g.beneficiary, amount);
    }

    /// @notice Investor marks stake start; claim allowed after 7 days.
    function markInvestorStakeHold(address investor) external {
        require(msg.sender == investor || msg.sender == address(stake), "auth");
        investorStakeReadyAt[investor] = uint64(block.timestamp + 7 days);
    }

    /// @notice Distributor pulls for ecosystem/mining programmatic releases.
    function pullForDistribution(uint256 id, uint256 amount, address to) external nonReentrant {
        require(msg.sender == distributor, "distributor");
        Grant storage g = grants[id];
        require(g.category == Category.Ecosystem || g.category == Category.Mining, "cat");
        uint256 c = claimable(id);
        require(amount > 0 && amount <= c, "amount");
        g.claimed += amount;
        karma.safeTransfer(to, amount);
        emit Claimed(id, to, amount);
    }

    function _miningVested(uint256 total, uint64 start, uint256 t) internal pure returns (uint256) {
        // Year1 50%, Year2 25%, Year3 12.5%, Year4 12.5% residual linearized monthly within year
        if (t <= start) return 0;
        uint256[4] memory yearShare = [
            (total * 50) / 100,
            (total * 25) / 100,
            (total * 125) / 1000,
            (total * 125) / 1000
        ];
        uint256 vested;
        for (uint256 y = 0; y < 4; y++) {
            uint256 yStart = start + y * 365 days;
            uint256 yEnd = yStart + 365 days;
            if (t >= yEnd) {
                vested += yearShare[y];
            } else if (t > yStart) {
                vested += (yearShare[y] * (t - yStart)) / 365 days;
                break;
            } else {
                break;
            }
        }
        return vested > total ? total : vested;
    }
}