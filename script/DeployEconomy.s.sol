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
import {SettlementMirror} from "../src/integration/SettlementMirror.sol";
import {FeeBridge} from "../src/integration/FeeBridge.sol";
import {CoreEscrowAdapter} from "../src/integration/CoreEscrowAdapter.sol";
import {ContributorRegistry} from "../src/cocreation/ContributorRegistry.sol";
import {ContributionLedger} from "../src/cocreation/ContributionLedger.sol";
import {CocreationScoreView} from "../src/cocreation/CocreationScoreView.sol";
import {KarmaEconomyConstants} from "../src/libraries/KarmaEconomyConstants.sol";

/// @notice Deploy full karma-economy stack with revenue mode OFF and karma-core bridge wiring.
/// @dev Read path uses SettlementMirror (IKarmaCoreView). Write path authorizes KARMA_CORE_ADDRESS
///      (KarmaBilateral) on FeeBridge. Apply integrations/karma-core patch on AtoB101/Karma, then
///      call Bilateral.setTreasury / setFeeBridge (see WireKarmaCore.s.sol).
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
        ContributionNFT nft = new ContributionNFT(msg.sender); // temp minter → ContributionLedger
        KarmaVesting vesting = new KarmaVesting(address(karma), address(msig));

        // Phase-1: deployer is temporary controller/governance for bridge wiring.
        address deployer = msg.sender;
        SettlementMirror mirror = new SettlementMirror(deployer, address(0));

        DeveloperRewardPool devPool = new DeveloperRewardPool(usdc, deployer, address(mirror), address(nft));
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

        FeeBridge bridge = new FeeBridge(usdc, address(treasury), address(mirror), address(stake), deployer);
        CoreEscrowAdapter escrow = new CoreEscrowAdapter(address(mirror), deployer);
        // Temporary deployer governance so escrow adapter can be wired atomically.
        DisputeArbitrator arbitrator = new DisputeArbitrator(address(stake), deployer, address(mirror));
        KarmaGovernor governor = new KarmaGovernor(address(stake), address(treasury), address(msig));

        // Cocreation Score v1
        ContributorRegistry registry = new ContributorRegistry(deployer);
        ContributionLedger ledger = new ContributionLedger(address(registry), address(nft), deployer, deployer);
        CocreationScoreView scoreView = new CocreationScoreView(address(ledger), address(stake), deployer, deployer);
        nft.setMinter(address(ledger));
        devPool.setRegistry(address(registry));

        // Wire fee / GMV / escrow bridge
        bridge.setCore(karmaCore);
        mirror.setReporter(address(bridge), true);
        mirror.setReporter(address(escrow), true);
        escrow.setArbitrator(address(arbitrator));
        arbitrator.setCoreEscrowAdapter(address(escrow));
        arbitrator.setGovernance(address(msig));

        // Hand off temporary bridge / cocreation roles to multisig
        mirror.setGovernance(address(msig));
        bridge.setGovernance(address(msig));
        escrow.setGovernance(address(msig));
        registry.setGovernance(address(msig));
        ledger.setGovernance(address(msig));
        ledger.setAccepter(address(msig));
        scoreView.setGovernance(address(msig));
        scoreView.setSettleOracle(address(msig));

        devPool.setTreasury(address(treasury));
        stakerPool.setTreasury(address(treasury));
        verifierPool.setTreasury(address(treasury));
        buyBurn.setTreasury(address(treasury));

        // Post-deploy (via 7/7 multisig): treasury.setGovernance(governor), stake.setGovernance(governor),
        // stake.setArbitrator(arbitrator), arbitrator.setNodePool(verifierPool), vesting.setStake(stake).
        // On Karma Bilateral (after applying feebridge patch): setTreasury + setFeeBridge.

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
        console2.log("SettlementMirror", address(mirror));
        console2.log("FeeBridge", address(bridge));
        console2.log("CoreEscrowAdapter", address(escrow));
        console2.log("ContributorRegistry", address(registry));
        console2.log("ContributionLedger", address(ledger));
        console2.log("CocreationScoreView", address(scoreView));
        console2.log("KarmaCore(Bilateral)", karmaCore);
        console2.log("FEE_BPS", KarmaEconomyConstants.FEE_BPS);
        console2.log("enableRevenueMode", treasury.enableRevenueMode());
        console2.log("NEXT: Bilateral.setTreasury(treasury) + setFeeBridge(feeBridge)");

        vm.stopBroadcast();
    }
}
