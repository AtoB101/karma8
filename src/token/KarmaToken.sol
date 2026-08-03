// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {KarmaEconomyConstants} from "../libraries/KarmaEconomyConstants.sol";

/// @title KarmaToken ($KARMA)
/// @notice Fixed supply 1B, permanently non-mintable after construction.
contract KarmaToken is ERC20 {
    error MintDisabled();

    constructor(address initialHolder) ERC20("KARMA", "KARMA") {
        require(initialHolder != address(0), "holder=0");
        _mint(initialHolder, KarmaEconomyConstants.KARMA_TOTAL_SUPPLY);
    }

    /// @dev Explicitly document zero inflation. No mint function exists after deploy.
    function mint(address, uint256) external pure {
        revert MintDisabled();
    }
}