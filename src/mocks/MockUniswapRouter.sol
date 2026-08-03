// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2RouterMinimal} from "../interfaces/IUniswapV2RouterMinimal.sol";

/// @dev 1 USDC (6 dec) -> 1e12 KARMA wei for simple tests, or 1:1e12 scaled.
contract MockUniswapRouter is IUniswapV2RouterMinimal {
    uint256 public rate = 1e12; // karma wei per usdc base unit

    function setRate(uint256 rate_) external {
        rate = rate_;
    }

    function WETH() external pure returns (address) {
        return address(0);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256
    ) external returns (uint256[] memory amounts) {
        require(path.length == 2, "path");
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        uint256 out = amountIn * rate;
        require(out >= amountOutMin, "slippage");
        // Mint-like: router must hold karma; pull from own balance
        IERC20(path[1]).transfer(to, out);
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = out;
    }
}
