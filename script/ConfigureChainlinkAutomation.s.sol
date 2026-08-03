// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Treasury} from "../src/treasury/Treasury.sol";

/// @notice Helper to print Chainlink Automation registration parameters for Treasury.
/// @dev Actual registration is performed via Chainlink Automation Registry UI / keeper registrar.
contract ConfigureChainlinkAutomation is Script {
    function run() external view {
        address treasuryAddr = vm.envAddress("TREASURY_ADDRESS");
        Treasury treasury = Treasury(treasuryAddr);

        console2.log("=== Chainlink Automation Config ===");
        console2.log("Target contract:", treasuryAddr);
        console2.log("checkUpkeep selector: checkUpkeep(bytes)");
        console2.log("performUpkeep selector: performUpkeep(bytes)");
        console2.log("Recommended interval seconds:", uint256(7 days));
        console2.log("enableRevenueMode:", treasury.enableRevenueMode());
        console2.log("lastDistributionAt:", treasury.lastDistributionAt());
        console2.log("Note: upkeep is a no-op while enableRevenueMode=false");
    }
}