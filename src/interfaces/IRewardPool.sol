// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRewardPool {
    /// @notice Called by Treasury when distributing USDC under revenue mode.
    function notifyReward(uint256 amount) external;
}
