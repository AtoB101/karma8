// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IRewardPool} from "../interfaces/IRewardPool.sol";
import {IMultiTierStake} from "../interfaces/IMultiTierStake.sol";

/// @title VerifierNodePool
/// @notice Receives 20% treasury USDC; monthly settlement to active compliant verifiers.
contract VerifierNodePool is IRewardPool, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdc;
    IMultiTierStake public immutable stake;
    address public treasury;
    address public arbitrator;
    bool public revenueMode;

    uint256 public pendingRewards;
    uint64 public periodStart;
    uint64 public periodEnd;
    mapping(address => uint256) public claimableOf;
    mapping(address => uint256) public accuracyScore; // maintained by arbitrator

    event RewardNotified(uint256 amount);
    event PeriodSettled(uint64 start, uint64 end, uint256 reward, uint256 nodes);
    event Claimed(address indexed node, uint256 amount);
    event AccuracyUpdated(address indexed node, uint256 score);
    event RevenueModeUpdated(bool enabled);

    error Unauthorized();
    error RevenueOff();

    modifier onlyTreasury() {
        if (msg.sender != treasury) revert Unauthorized();
        _;
    }

    constructor(address usdc_, address stake_, address treasury_) {
        require(usdc_ != address(0) && stake_ != address(0) && treasury_ != address(0), "zero");
        usdc = IERC20(usdc_);
        stake = IMultiTierStake(stake_);
        treasury = treasury_;
        periodStart = uint64(block.timestamp);
        periodEnd = uint64(block.timestamp + 30 days);
    }

    function setTreasury(address t) external onlyTreasury {
        require(t != address(0), "zero");
        treasury = t;
    }

    function setArbitrator(address a) external onlyTreasury {
        arbitrator = a;
    }

    function setRevenueMode(bool enabled) external onlyTreasury {
        revenueMode = enabled;
        emit RevenueModeUpdated(enabled);
    }

    function notifyReward(uint256 amount) external override onlyTreasury {
        if (!revenueMode) revert RevenueOff();
        if (amount == 0) return;
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        pendingRewards += amount;
        emit RewardNotified(amount);
    }

    function setAccuracy(address node, uint256 score) external {
        if (msg.sender != arbitrator && msg.sender != treasury) revert Unauthorized();
        accuracyScore[node] = score;
        emit AccuracyUpdated(node, score);
    }

    function settlePeriod() external nonReentrant {
        if (!revenueMode) revert RevenueOff();
        require(block.timestamp >= periodEnd, "period");
        uint256 reward = pendingRewards;
        pendingRewards = 0;

        uint256 n = stake.verifierCount();
        uint256 totalScore;
        address[] memory nodes = new address[](n);
        uint256[] memory scores = new uint256[](n);
        uint256 active;

        for (uint256 i = 0; i < n; i++) {
            address node = stake.verifierAt(i);
            if (!stake.isActiveVerifier(node)) continue;
            uint256 s = accuracyScore[node];
            if (s == 0) s = 1; // default equal weight if unset
            nodes[active] = node;
            scores[active] = s;
            totalScore += s;
            active++;
        }

        if (reward > 0 && totalScore > 0) {
            for (uint256 i = 0; i < active; i++) {
                claimableOf[nodes[i]] += (reward * scores[i]) / totalScore;
            }
        }

        uint64 settledStart = periodStart;
        uint64 settledEnd = periodEnd;
        periodStart = uint64(block.timestamp);
        periodEnd = uint64(block.timestamp + 30 days);
        emit PeriodSettled(settledStart, settledEnd, reward, active);
    }

    function claim() external nonReentrant {
        if (!revenueMode) revert RevenueOff();
        uint256 amount = claimableOf[msg.sender];
        require(amount > 0, "zero");
        claimableOf[msg.sender] = 0;
        usdc.safeTransfer(msg.sender, amount);
        emit Claimed(msg.sender, amount);
    }
}
