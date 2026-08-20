// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
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
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {MockUniswapRouter} from "../src/mocks/MockUniswapRouter.sol";
import {SettlementMirror} from "../src/integration/SettlementMirror.sol";
import {FeeBridge} from "../src/integration/FeeBridge.sol";
import {ReferenceSettlementCore} from "../src/integration/ReferenceSettlementCore.sol";
import {CoreEscrowAdapter} from "../src/integration/CoreEscrowAdapter.sol";
import {ContributorRegistry} from "../src/cocreation/ContributorRegistry.sol";
import {ContributionLedger} from "../src/cocreation/ContributionLedger.sol";
import {CocreationScoreView} from "../src/cocreation/CocreationScoreView.sol";
import {KarmaEconomyConstants} from "../src/libraries/KarmaEconomyConstants.sol";

/// @notice One-shot local/demo deployment writing deployments/local.json
contract DeployLocalDemo is Script {
    using stdJson for string;

    function run() external {
        address[7] memory owners = [
            vm.envOr("MSIG_OWNER_0", address(0x1)),
            vm.envOr("MSIG_OWNER_1", address(0x2)),
            vm.envOr("MSIG_OWNER_2", address(0x3)),
            vm.envOr("MSIG_OWNER_3", address(0x4)),
            vm.envOr("MSIG_OWNER_4", address(0x5)),
            vm.envOr("MSIG_OWNER_5", address(0x6)),
            vm.envOr("MSIG_OWNER_6", address(0x7))
        ];

        vm.startBroadcast();
        address deployer = msg.sender;

        MultiSigWallet msig = new MultiSigWallet(owners);
        MockUSDC usdc = new MockUSDC();
        MockUniswapRouter router = new MockUniswapRouter();
        KarmaToken karma = new KarmaToken(deployer);
        MultiTierStake stake = new MultiTierStake(address(karma), deployer);
        ContributionNFT nft = new ContributionNFT(deployer);
        KarmaVesting vesting = new KarmaVesting(address(karma), deployer);

        SettlementMirror mirror = new SettlementMirror(deployer, address(0));

        DeveloperRewardPool devPool = new DeveloperRewardPool(address(usdc), deployer, address(mirror), address(nft));
        StakerRewardPool stakerPool = new StakerRewardPool(address(usdc), address(stake), deployer);
        VerifierNodePool verifierPool = new VerifierNodePool(address(usdc), address(stake), deployer);
        AutoBuyBurn buyBurn = new AutoBuyBurn(address(usdc), address(karma), deployer, address(router));

        Treasury treasury = new Treasury(
            address(usdc),
            deployer,
            address(devPool),
            address(stakerPool),
            address(verifierPool),
            address(buyBurn),
            address(0)
        );

        FeeBridge bridge = new FeeBridge(address(usdc), address(treasury), address(mirror), address(stake), deployer);
        ReferenceSettlementCore core = new ReferenceSettlementCore(address(usdc), address(bridge), deployer);
        CoreEscrowAdapter escrow = new CoreEscrowAdapter(address(mirror), deployer);
        DisputeArbitrator arbitrator = new DisputeArbitrator(address(stake), deployer, address(mirror));
        KarmaGovernor governor = new KarmaGovernor(address(stake), address(treasury), deployer);

        ContributorRegistry registry = new ContributorRegistry(deployer);
        ContributionLedger ledger = new ContributionLedger(address(registry), address(nft), deployer, deployer);
        CocreationScoreView scoreView =
            new CocreationScoreView(address(ledger), address(stake), deployer, deployer);
        nft.setMinter(address(ledger));
        devPool.setRegistry(address(registry));

        // Wire
        devPool.setTreasury(address(treasury));
        stakerPool.setTreasury(address(treasury));
        verifierPool.setTreasury(address(treasury));
        buyBurn.setTreasury(address(treasury));
        bridge.setCore(address(core));
        mirror.setReporter(address(bridge), true);
        mirror.setReporter(address(escrow), true);
        escrow.setArbitrator(address(arbitrator));
        escrow.setCoreTarget(address(core));
        core.setEscrowController(address(escrow));
        arbitrator.setNodePool(address(verifierPool));
        arbitrator.setCoreEscrowAdapter(address(escrow));
        verifierPool.setArbitrator(address(arbitrator));
        stake.setArbitrator(address(arbitrator));
        vesting.setStake(address(stake));
        treasury.setKarmaCore(address(core));
        treasury.setGovernance(address(governor));
        stake.setGovernance(address(governor));

        // Seed demo liquidity for buyback router + faucet
        karma.transfer(address(router), 20_000_000 ether);
        usdc.mint(deployer, 50_000_000e6);

        string memory json = "demo";
        vm.serializeAddress(json, "multiSig", address(msig));
        vm.serializeAddress(json, "usdc", address(usdc));
        vm.serializeAddress(json, "karma", address(karma));
        vm.serializeAddress(json, "stake", address(stake));
        vm.serializeAddress(json, "treasury", address(treasury));
        vm.serializeAddress(json, "governor", address(governor));
        vm.serializeAddress(json, "developerPool", address(devPool));
        vm.serializeAddress(json, "stakerPool", address(stakerPool));
        vm.serializeAddress(json, "verifierPool", address(verifierPool));
        vm.serializeAddress(json, "buyBurn", address(buyBurn));
        vm.serializeAddress(json, "contributionNft", address(nft));
        vm.serializeAddress(json, "vesting", address(vesting));
        vm.serializeAddress(json, "arbitrator", address(arbitrator));
        vm.serializeAddress(json, "settlementMirror", address(mirror));
        vm.serializeAddress(json, "feeBridge", address(bridge));
        vm.serializeAddress(json, "referenceCore", address(core));
        vm.serializeAddress(json, "escrowAdapter", address(escrow));
        vm.serializeAddress(json, "contributorRegistry", address(registry));
        vm.serializeAddress(json, "contributionLedger", address(ledger));
        vm.serializeAddress(json, "cocreationScoreView", address(scoreView));
        vm.serializeBool(json, "enableRevenueMode", treasury.enableRevenueMode());
        vm.serializeUint(json, "feeBps", KarmaEconomyConstants.FEE_BPS);
        string memory out = vm.serializeUint(json, "chainId", block.chainid);
        vm.writeJson(out, "deployments/local.json");

        console2.log("Wrote deployments/local.json");
        console2.log("Treasury", address(treasury));
        console2.log("ReferenceCore", address(core));
        console2.log("ContributionLedger", address(ledger));
        console2.log("enableRevenueMode", treasury.enableRevenueMode());

        vm.stopBroadcast();
    }
}
