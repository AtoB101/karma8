// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IRewardPool} from "../interfaces/IRewardPool.sol";
import {IMultiTierStake} from "../interfaces/IMultiTierStake.sol";

/// @title StakerRewardPool
/// @notice Receives 30% treasury USDC and distributes by staking voting weight.
contract StakerRewardPool is IRewardPool, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdc;
    IMultiTierStake public immutable stake;
    address public treasury;
    bool public revenueMode;

    uint256 public rewardPerWeightStored; // 1e18 scaled
    uint256 public totalDistributed;
    mapping(address => uint256) public userRewardPerWeightPaid;
    mapping(address => uint256) public rewards;

    event RewardNotified(uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event RevenueModeUpdated(bool enabled);
    event TreasuryUpdated(address indexed treasury);

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
    }

    function setTreasury(address t) external onlyTreasury {
        require(t != address(0), "zero");
        treasury = t;
        emit TreasuryUpdated(t);
    }

    function setRevenueMode(bool enabled) external onlyTreasury {
        revenueMode = enabled;
        emit RevenueModeUpdated(enabled);
    }

    function notifyReward(uint256 amount) external override onlyTreasury {
        if (!revenueMode) revert RevenueOff();
        if (amount == 0) return;
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        uint256 tw = _totalWeight();
        if (tw > 0) {
            rewardPerWeightStored += (amount * 1e18) / tw;
        }
        totalDistributed += amount;
        emit RewardNotified(amount);
    }

    function earned(address account) public view returns (uint256) {
        uint256 weight = stake.votingWeight(account);
        uint256 accrued = (weight * (rewardPerWeightStored - userRewardPerWeightPaid[account])) / 1e18;
        return rewards[account] + accrued;
    }

    function updateAccount(address account) public {
        rewards[account] = earned(account);
        userRewardPerWeightPaid[account] = rewardPerWeightStored;
    }

    function claim() external nonReentrant {
        if (!revenueMode) revert RevenueOff();
        updateAccount(msg.sender);
        uint256 amount = rewards[msg.sender];
        require(amount > 0, "zero");
        rewards[msg.sender] = 0;
        usdc.safeTransfer(msg.sender, amount);
        emit Claimed(msg.sender, amount);
    }

    function _totalWeight() internal view returns (uint256) {
        return stake.totalVotingWeight();
    }
}
