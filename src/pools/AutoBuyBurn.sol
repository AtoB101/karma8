// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IRewardPool} from "../interfaces/IRewardPool.sol";
import {IUniswapV2RouterMinimal} from "../interfaces/IUniswapV2RouterMinimal.sol";
import {KarmaEconomyConstants} from "../libraries/KarmaEconomyConstants.sol";

/// @title AutoBuyBurn
/// @notice Receives 10% treasury USDC; swaps to KARMA via Uniswap and burns.
/// @dev Testnet/measured stage: swap paused; only accumulates USDC.
contract AutoBuyBurn is IRewardPool, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdc;
    IERC20 public immutable karma;
    IUniswapV2RouterMinimal public router;
    address public treasury;
    bool public revenueMode;
    bool public swapPaused = true; // forced pause for testnet

    uint256 public totalUsdcReceived;
    uint256 public totalKarmaBurned;

    event RewardNotified(uint256 amount);
    event Burned(uint256 usdcIn, uint256 karmaOut);
    event SwapPausedUpdated(bool paused);
    event RevenueModeUpdated(bool enabled);
    event RouterUpdated(address indexed router);

    error Unauthorized();
    error RevenueOff();
    error SwapPaused();

    modifier onlyTreasury() {
        if (msg.sender != treasury) revert Unauthorized();
        _;
    }

    constructor(address usdc_, address karma_, address treasury_, address router_) {
        require(usdc_ != address(0) && karma_ != address(0) && treasury_ != address(0), "zero");
        usdc = IERC20(usdc_);
        karma = IERC20(karma_);
        treasury = treasury_;
        router = IUniswapV2RouterMinimal(router_);
    }

    function setTreasury(address t) external onlyTreasury {
        require(t != address(0), "zero");
        treasury = t;
    }

    function setRevenueMode(bool enabled) external onlyTreasury {
        revenueMode = enabled;
        emit RevenueModeUpdated(enabled);
    }

    function setSwapPaused(bool paused) external onlyTreasury {
        swapPaused = paused;
        emit SwapPausedUpdated(paused);
    }

    function setRouter(address router_) external onlyTreasury {
        router = IUniswapV2RouterMinimal(router_);
        emit RouterUpdated(router_);
    }

    function notifyReward(uint256 amount) external override onlyTreasury {
        if (!revenueMode) revert RevenueOff();
        if (amount == 0) return;
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        totalUsdcReceived += amount;
        emit RewardNotified(amount);
    }

    /// @notice Execute buyback+burn. Disabled while swapPaused (testnet default).
    function executeBuyBurn(uint256 amountIn, uint256 amountOutMin) external nonReentrant {
        if (!revenueMode) revert RevenueOff();
        if (swapPaused) revert SwapPaused();
        require(address(router) != address(0), "router");
        require(amountIn > 0 && amountIn <= usdc.balanceOf(address(this)), "amount");

        usdc.forceApprove(address(router), amountIn);
        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(karma);

        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn, amountOutMin, path, address(this), block.timestamp
        );
        uint256 karmaOut = amounts[amounts.length - 1];
        karma.safeTransfer(KarmaEconomyConstants.BURN_ADDRESS, karmaOut);
        totalKarmaBurned += karmaOut;
        emit Burned(amountIn, karmaOut);
    }
}