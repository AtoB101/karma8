// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {KarmaToken} from "../src/token/KarmaToken.sol";
import {MultiTierStake} from "../src/staking/MultiTierStake.sol";
import {IMultiTierStake} from "../src/interfaces/IMultiTierStake.sol";
import {FeeBridge} from "../src/integration/FeeBridge.sol";
import {SettlementMirror} from "../src/integration/SettlementMirror.sol";
import {ReferenceSettlementCore} from "../src/integration/ReferenceSettlementCore.sol";
import {ContributorRegistry} from "../src/cocreation/ContributorRegistry.sol";
import {IContributorRegistry} from "../src/interfaces/IContributorRegistry.sol";
import {Treasury} from "../src/treasury/Treasury.sol";

/// @notice Seed multi-scenario settles for Telegram MiniApp local demos.
/// @dev Requires deployments/local.json from DeployLocalDemo. Broadcast as anvil #0.
contract SeedTelegramScenarios is Script {
    using stdJson for string;

    // Anvil default account #1 key / addresses (#2 seller, #3 builder)
    uint256 internal constant BUYER_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    address internal constant BUYER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address internal constant SELLER = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address internal constant BUILDER = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    function run() external {
        string memory raw = vm.readFile("deployments/local.json");
        address usdcAddr = raw.readAddress(".usdc");
        address karmaAddr = raw.readAddress(".karma");
        address stakeAddr = raw.readAddress(".stake");
        address coreAddr = raw.readAddress(".referenceCore");
        address bridgeAddr = raw.readAddress(".feeBridge");
        address mirrorAddr = raw.readAddress(".settlementMirror");
        address registryAddr = raw.readAddress(".contributorRegistry");
        address treasuryAddr = raw.readAddress(".treasury");

        MockUSDC usdc = MockUSDC(usdcAddr);
        KarmaToken karma = KarmaToken(karmaAddr);
        MultiTierStake stake = MultiTierStake(stakeAddr);
        ReferenceSettlementCore core = ReferenceSettlementCore(coreAddr);
        SettlementMirror mirror = SettlementMirror(mirrorAddr);
        ContributorRegistry registry = ContributorRegistry(registryAddr);
        FeeBridge bridge = FeeBridge(bridgeAddr);
        Treasury treasury = Treasury(treasuryAddr);

        bytes32 orderNormal = keccak256("tg-scenario-normal-v1");
        bytes32 orderSelf = keccak256("tg-scenario-selfdeal-v1");
        uint256 amountNormal = 1_000_000e6;
        uint256 amountSelf = 250_000e6;

        vm.startBroadcast();
        address deployer = msg.sender;

        IContributorRegistry.Role[] memory roles = new IContributorRegistry.Role[](1);
        roles[0] = IContributorRegistry.Role.BUILDER;
        bytes32[] memory tracks = new bytes32[](1);
        tracks[0] = keccak256("telegram-demo");
        if (!registry.isActive(BUILDER)) {
            registry.registerFor(BUILDER, roles, tracks);
        }
        if (!registry.isActive(deployer)) {
            registry.registerFor(deployer, roles, tracks);
        }

        usdc.mint(BUYER, amountNormal + amountSelf + 1_000e6);
        karma.transfer(deployer, 100_000 ether);
        karma.approve(address(stake), type(uint256).max);
        if (stake.stakeOf(deployer) == 0) {
            stake.stake(50_000 ether, IMultiTierStake.Tier.Developer);
        }

        vm.stopBroadcast();

        vm.startBroadcast(BUYER_KEY);
        usdc.approve(address(core), type(uint256).max);
        core.openOrder(orderNormal, SELLER, BUILDER, amountNormal);
        core.settle(orderNormal);

        uint256 gmvBefore = mirror.lifetimeDeveloperGmv(BUILDER);
        core.openOrder(orderSelf, BUYER, BUILDER, amountSelf);
        core.settle(orderSelf);
        uint256 gmvAfter = mirror.lifetimeDeveloperGmv(BUILDER);
        vm.stopBroadcast();

        require(gmvAfter == gmvBefore, "self-deal credited GMV");

        string memory j = "scenarios";
        vm.serializeAddress(j, "buyer", BUYER);
        vm.serializeAddress(j, "seller", SELLER);
        vm.serializeAddress(j, "builder", BUILDER);
        vm.serializeAddress(j, "deployer", deployer);
        vm.serializeBytes32(j, "orderNormal", orderNormal);
        vm.serializeBytes32(j, "orderSelfDeal", orderSelf);
        vm.serializeUint(j, "amountNormalUsdc", amountNormal);
        vm.serializeUint(j, "amountSelfDealUsdc", amountSelf);
        vm.serializeUint(j, "builderLifetimeGmv", gmvAfter);
        vm.serializeBool(j, "enableRevenueMode", treasury.enableRevenueMode());
        vm.serializeAddress(j, "feeBridgeCore", bridge.core());
        vm.serializeBool(j, "selfDealDidNotCreditGmv", gmvAfter == gmvBefore);
        string memory out = vm.serializeUint(j, "chainId", block.chainid);
        vm.writeJson(out, "deployments/scenarios.json");

        console2.log("SeedTelegramScenarios OK");
        console2.log("BUILDER GMV", gmvAfter);
        console2.log("FeeBridge.core", bridge.core());
        console2.log("Wrote deployments/scenarios.json");
    }
}
