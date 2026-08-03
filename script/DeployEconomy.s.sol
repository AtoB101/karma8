// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {KarmaToken} from "../src/token/KarmaToken.sol";
import {KarmaVesting} from "../src/token/KarmaVesting.sol";
import {MultiSigWallet} from "../src/governance/MultiSigWallet.sol";
import {KarmaGovernor} from "../src/governance/KarmaGovernor.sol";
import {MultiTierStake} from "../src/staking/MultiTierStake.sol";
import {ContributionNFT} from "../src/nft/ContributionNFT.sol";
import {Treasury} from "../src/treasury/Treasury.sol";
import {DeveloperRewardPool} from "../src/pools/DeveloperRewardPool.sol";
import {StakerRewardPool} from "../src/pools/StakerRewardPool.sol";
import {VerifierNodePool} from "../src/pools/VerifierNodePool.sol";
import {AutoBuyBurn} from "../src/pools/AutoBuyBurn.sol";
import {DisputeArbitrator} from "../src/arbitration/DisputeArbitrator.sol";
import {KarmaEconomyConstants} from "../src/libraries/KarmaEconomyConstants.sol";

/// @notice Deploy full karma-economy stack with revenue mode OFF.
contract DeployEconomy is Script {
    function run() external {
        address usdc = vm.envAddress("USDC_ADDRESS");
        address karmaCore = vm.envAddress("KARMA_CORE_ADDRESS");
        address router = vm.envOr("UNISWAP_ROUTER", address(0));

        address[7] memory owners = [
            vm.envAddress("MSIG_OWNER_0"),
            vm.envAddress("MSIG_OWNER_1"),
            vm.envAddress("MSIG_OWNER_2"),
            vm.envAddress("MSIG_OWNER_3"),
            vm.envAddress("MSIG_OWNER_4"),
            vm.envAddress("MSIG_OWNER_5"),
            vm.envAddress("MSIG_OWNER_6")
        ];

        vm.startBroadcast();

        MultiSigWallet msig = new MultiSigWallet(owners);
        KarmaToken karma = new KarmaToken(address(msig));
        MultiTierStake stake = new MultiTierStake(address(karma), address(msig));
        ContributionNFT nft = new ContributionNFT(address(msig));
        KarmaVesting vesting = new KarmaVesting(address(karma), address(msig));

        // Phase-1 pools with deployer as temporary treasury controller
        address deployer = msg.sender;
        DeveloperRewardPool devPool = new DeveloperRewardPool(usdc, deployer, karmaCore, address(nft));
        StakerRewardPool stakerPool = new StakerRewardPool(usdc, address(stake), deployer);
        VerifierNodePool verifierPool = new VerifierNodePool(usdc, address(stake), deployer);
        AutoBuyBurn buyBurn = new AutoBuyBurn(usdc, address(karma), deployer, router);

        Treasury treasury = new Treasury(
            usdc,
            address(msig),
            address(devPool),
            address(stakerPool),
            address(verifierPool),
            address(buyBurn),
            karmaCore
        );

        devPool.setTreasury(address(treasury));
        stakerPool.setTreasury(address(treasury));
        verifierPool.setTreasury(address(treasury));
        buyBurn.setTreasury(address(treasury));

        DisputeArbitrator arbitrator = new DisputeArbitrator(address(stake), address(msig), karmaCore);
        KarmaGovernor governor = new KarmaGovernor(address(stake), address(treasury), address(msig));

        // Post-deploy (via 7/7 multisig): treasury.setGovernance(governor), stake.setGovernance(governor),
        // stake.setArbitrator(arbitrator), arbitrator.setNodePool(verifierPool), vesting.setStake(stake).

        console2.log("MultiSig", address(msig));
        console2.log("KARMA", address(karma));
        console2.log("Stake", address(stake));
        console2.log("ContributionNFT", address(nft));
        console2.log("Vesting", address(vesting));
        console2.log("Treasury", address(treasury));
        console2.log("DeveloperPool", address(devPool));
        console2.log("StakerPool", address(stakerPool));
        console2.log("VerifierPool", address(verifierPool));
        console2.log("AutoBuyBurn", address(buyBurn));
        console2.log("Arbitrator", address(arbitrator));
        console2.log("Governor", address(governor));
        console2.log("FEE_BPS", KarmaEconomyConstants.FEE_BPS);
        console2.log("enableRevenueMode", treasury.enableRevenueMode());

        vm.stopBroadcast();
    }
}
