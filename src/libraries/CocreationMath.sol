// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {KarmaEconomyConstants} from "./KarmaEconomyConstants.sol";

/// @title CocreationMath
/// @notice Pure helpers for Cocreation Score v1 (W×Q×T, decay, R_contrib).
library CocreationMath {
    uint256 internal constant BPS = 10_000;

    function cEvent(uint256 wBase, uint256 qBps, uint256 tBps) internal pure returns (uint256) {
        return (wBase * qBps * tBps) / (BPS * BPS);
    }

    function decayBps(uint256 ageSeconds) internal pure returns (uint256) {
        uint256 ageDays = ageSeconds / 1 days;
        if (ageDays <= KarmaEconomyConstants.DECAY_HOT_DAYS) return KarmaEconomyConstants.DECAY_HOT_BPS;
        if (ageDays <= KarmaEconomyConstants.DECAY_WARM_DAYS) return KarmaEconomyConstants.DECAY_WARM_BPS;
        return KarmaEconomyConstants.DECAY_COLD_BPS;
    }

    function applyDecay(uint256 amount, uint256 ageSeconds) internal pure returns (uint256) {
        return (amount * decayBps(ageSeconds)) / BPS;
    }

    /// @dev R_contrib = min(10000, 10000 * log2(1+C) / log2(1+C_ref)) — proportional to log1p ratio.
    function rContrib(uint256 cActive) internal pure returns (uint256) {
        if (cActive == 0) return 0;
        uint256 num = Math.log2(cActive + 1);
        uint256 den = Math.log2(KarmaEconomyConstants.COCREATION_C_REF + 1);
        if (den == 0) return 0;
        uint256 r = (10_000 * num) / den;
        return r > 10_000 ? 10_000 : r;
    }
}
