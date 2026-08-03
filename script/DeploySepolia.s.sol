// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {DeployEconomy} from "./DeployEconomy.s.sol";

/// @notice Sepolia deployment entry — wraps DeployEconomy and prints go-live wiring tips.
contract DeploySepolia is Script {
    function run() external {
        console2.log("Deploying karma-economy to chain", block.chainid);
        require(block.chainid == 11155111 || block.chainid == 31337, "sepolia/local only");
        DeployEconomy deploy = new DeployEconomy();
        deploy.run();
        console2.log("Next:");
        console2.log("1) FeeBridge.setCore(KarmaBilateral)");
        console2.log("2) Bilateral.setTreasury + setFeeBridge");
        console2.log("3) Register Chainlink Automation on Treasury");
        console2.log("4) Keep enableRevenueMode=false until governance vote");
    }
}
