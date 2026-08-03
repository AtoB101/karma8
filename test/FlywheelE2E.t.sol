// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {EconomyFixture} from "./helpers/EconomyFixture.sol";
import {SettlementMirror} from "../src/integration/SettlementMirror.sol";
import {FeeBridge} from "../src/integration/FeeBridge.sol";
import {ReferenceSettlementCore} from "../src/integration/ReferenceSettlementCore.sol";
import {CoreEscrowAdapter} from "../src/integration/CoreEscrowAdapter.sol";
import {IMultiTierStake} from "../src/interfaces/IMultiTierStake.sol";
import {AutoBuyBurn} from "../src/pools/AutoBuyBurn.sol";

/// @notice Commercial-path rehearsal: free settle → gov enable → fee settle → weekly split → claims → disable.
contract FlywheelE2ETest is EconomyFixture {
    SettlementMirror internal mirror;
    FeeBridge internal bridge;
    ReferenceSettlementCore internal core;
    CoreEscrowAdapter internal escrow;

    address internal buyer;
    address internal seller;
    address internal developer;
    address internal alice;

    function setUp() public {
        setUpEconomy();

        buyer = makeAddr("buyer");
        seller = makeAddr("seller");
        developer = makeAddr("developer");
        alice = makeAddr("alice");

        mirror = new SettlementMirror(address(this), address(0));
        bridge = new FeeBridge(address(usdc), address(treasury), address(mirror), address(stake), address(this));
        core = new ReferenceSettlementCore(address(usdc), address(bridge), address(this));
        escrow = new CoreEscrowAdapter(address(mirror), address(this));

        bridge.setCore(address(core));
        mirror.setReporter(address(bridge), true);
        mirror.setReporter(address(escrow), true);
        escrow.setArbitrator(address(arbitrator));
        arbitrator.setKarmaCore(address(mirror));
        arbitrator.setCoreEscrowAdapter(address(escrow));
        treasury.setKarmaCore(address(core));

        vm.prank(address(treasury));
        devPool.setKarmaCore(address(mirror));

        karma.transfer(alice, 2_000_000 ether);
        vm.startPrank(alice);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(2_000_000 ether, IMultiTierStake.Tier.Public);
        vm.stopPrank();

        usdc.mint(buyer, 10_000_000e6);
    }

    function test_ColdStartFreeThenFlywheelThenShutdown() public {
        // Phase 1: cold start — settle without fees
        bytes32 order1 = keccak256("free-1");
        vm.startPrank(buyer);
        usdc.approve(address(core), 1_000_000e6);
        core.openOrder(order1, seller, developer, 1_000_000e6);
        core.settle(order1);
        vm.stopPrank();

        assertEq(usdc.balanceOf(seller), 1_000_000e6);
        assertEq(usdc.balanceOf(address(treasury)), 0);
        assertEq(mirror.getDeveloperGmv(developer, 0, uint64(block.timestamp + 1)), 1_000_000e6);

        // Phase 2: governance enables revenue
        _enableRevenueViaGov(alice);
        assertTrue(treasury.enableRevenueMode());
        assertEq(bridge.quoteFeeBps(developer), 20);

        // Developer stake for fee discount later
        karma.transfer(developer, 100_000 ether);
        vm.startPrank(developer);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(100_000 ether, IMultiTierStake.Tier.Developer);
        vm.stopPrank();
        assertEq(bridge.quoteFeeBps(developer), 10);

        // Phase 3: fee-on settle + weekly distribute + claims
        bytes32 order2 = keccak256("paid-1");
        uint256 amount = 1_000_000e6;
        uint256 fee = bridge.quoteFee(developer, amount); // 0.1% = 1000e6
        assertEq(fee, 1_000e6);

        vm.startPrank(buyer);
        usdc.approve(address(core), amount);
        core.openOrder(order2, seller, developer, amount);
        core.settle(order2);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(treasury)), fee);
        assertEq(usdc.balanceOf(seller), 1_000_000e6 + (amount - fee));

        // Register developer + NFT weight, then distribute
        vm.prank(address(treasury));
        (bool okMode,) = address(devPool).call(abi.encodeWithSignature("setRevenueMode(bool)", true));
        okMode;
        devPool.registerDeveloper(developer);
        nft.mint(developer, 50, "ipfs://contrib");

        vm.warp(block.timestamp + 7 days);
        treasury.performUpkeep("");

        assertEq(usdc.balanceOf(address(devPool)), (fee * 40) / 100);
        assertEq(usdc.balanceOf(address(stakerPool)), (fee * 30) / 100);
        assertEq(usdc.balanceOf(address(verifierPool)), (fee * 20) / 100);
        assertEq(usdc.balanceOf(address(buyBurn)), (fee * 10) / 100);

        // Staker can claim
        uint256 before = usdc.balanceOf(alice);
        stakerPool.updateAccount(alice);
        uint256 earned = stakerPool.earned(alice);
        assertGt(earned, 0);
        vm.prank(alice);
        stakerPool.claim();
        assertEq(usdc.balanceOf(alice), before + earned);

        // Buyback remains paused on testnet posture
        vm.expectRevert(AutoBuyBurn.SwapPaused.selector);
        buyBurn.executeBuyBurn(1, 0);

        // Phase 4: shutdown revenue again (free mode)
        vm.prank(alice);
        uint256 id = governor.proposeEnableRevenue(false, "back to free");
        vm.prank(alice);
        governor.vote(id, true);
        vm.warp(block.timestamp + 7 days + 1);
        governor.execute(id);
        assertFalse(treasury.enableRevenueMode());
        assertEq(bridge.quoteFeeBps(developer), 0);
    }
}
