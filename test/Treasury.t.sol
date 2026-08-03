// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {EconomyFixture} from "./helpers/EconomyFixture.sol";
import {Treasury} from "../src/treasury/Treasury.sol";
import {MultiTierStake} from "../src/staking/MultiTierStake.sol";
import {IMultiTierStake} from "../src/interfaces/IMultiTierStake.sol";
import {AutoBuyBurn} from "../src/pools/AutoBuyBurn.sol";

contract TreasuryTest is EconomyFixture {
    function setUp() public {
        setUpEconomy();
    }

    function test_ImmutableFeeAndSplits() public view {
        assertEq(treasury.feeBps(), 20);
        (uint256 a, uint256 b, uint256 c, uint256 d) = treasury.splitRatios();
        assertEq(a, 40);
        assertEq(b, 30);
        assertEq(c, 20);
        assertEq(d, 10);
        assertEq(a + b + c + d, 100);
    }

    function test_RevenueModeDefaultsOff() public view {
        assertFalse(treasury.enableRevenueMode());
        assertTrue(buyBurn.swapPaused());
    }

    function test_ReceiveFeesWithoutDistributionWhenOff() public {
        usdc.mint(address(this), 1_000_000e6);
        usdc.approve(address(treasury), 1_000_000e6);
        treasury.notifyFee(1_000_000e6);
        assertEq(usdc.balanceOf(address(treasury)), 1_000_000e6);

        vm.expectRevert(Treasury.RevenueOff.selector);
        treasury.distributeNow();
    }

    function test_PrivateTransferForbidden() public {
        vm.expectRevert(Treasury.PrivateTransferForbidden.selector);
        treasury.transfer(address(0xBEEF), 1);
    }

    function test_WeeklyDistributionSplits() public {
        address alice = makeAddr("alice");
        karma.transfer(alice, 2_000_000 ether);
        vm.startPrank(alice);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(1_000_000 ether, IMultiTierStake.Tier.Public);
        vm.stopPrank();

        _enableRevenueViaGov(alice);
        assertTrue(treasury.enableRevenueMode());
        assertTrue(stake.revenueMode());

        usdc.mint(address(this), 1_000_000e6);
        usdc.approve(address(treasury), 1_000_000e6);
        treasury.notifyFee(1_000_000e6);

        vm.warp(block.timestamp + 7 days);
        (bool needed,) = treasury.checkUpkeep("");
        assertTrue(needed);
        treasury.performUpkeep("");

        assertEq(usdc.balanceOf(address(devPool)), 400_000e6);
        assertEq(usdc.balanceOf(address(stakerPool)), 300_000e6);
        assertEq(usdc.balanceOf(address(verifierPool)), 200_000e6);
        assertEq(usdc.balanceOf(address(buyBurn)), 100_000e6);
        assertEq(buyBurn.totalUsdcReceived(), 100_000e6);
    }

    function test_BuyBurnPausedOnTestnet() public {
        address alice = makeAddr("alice");
        karma.transfer(alice, 1_000_000 ether);
        vm.startPrank(alice);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(1_000_000 ether, IMultiTierStake.Tier.Public);
        vm.stopPrank();
        _enableRevenueViaGov(alice);

        usdc.mint(address(this), 100e6);
        usdc.approve(address(treasury), 100e6);
        treasury.notifyFee(100e6);
        vm.warp(block.timestamp + 7 days);
        treasury.performUpkeep("");

        vm.expectRevert(AutoBuyBurn.SwapPaused.selector);
        buyBurn.executeBuyBurn(1e6, 0);
    }
}
