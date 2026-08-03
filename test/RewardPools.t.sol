// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {EconomyFixture} from "./helpers/EconomyFixture.sol";
import {MultiTierStake} from "../src/staking/MultiTierStake.sol";
import {IMultiTierStake} from "../src/interfaces/IMultiTierStake.sol";

contract RewardPoolsTest is EconomyFixture {
    function setUp() public {
        setUpEconomy();
    }

    function test_StakerClaimAfterDistribution() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        karma.transfer(alice, 1_000_000 ether);
        karma.transfer(bob, 1_000_000 ether);

        vm.startPrank(alice);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(1_000_000 ether, IMultiTierStake.Tier.Public);
        vm.stopPrank();

        vm.startPrank(bob);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(1_000_000 ether, IMultiTierStake.Tier.Public);
        vm.stopPrank();

        _enableRevenueViaGov(alice);

        usdc.mint(address(this), 1_000_000e6);
        usdc.approve(address(treasury), 1_000_000e6);
        treasury.notifyFee(1_000_000e6);
        vm.warp(block.timestamp + 7 days);
        treasury.performUpkeep("");

        stakerPool.updateAccount(alice);
        stakerPool.updateAccount(bob);

        uint256 eAlice = stakerPool.earned(alice);
        uint256 eBob = stakerPool.earned(bob);
        assertGt(eAlice, 0);
        assertEq(eAlice, eBob);

        vm.prank(alice);
        stakerPool.claim();
        assertEq(usdc.balanceOf(alice), eAlice);
    }

    function test_DeveloperPoolEpochByGmvAndNft() public {
        address alice = makeAddr("alice");
        address dev1 = makeAddr("dev1");
        address dev2 = makeAddr("dev2");
        karma.transfer(alice, 1_000_000 ether);
        vm.startPrank(alice);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(1_000_000 ether, IMultiTierStake.Tier.Public);
        vm.stopPrank();
        _enableRevenueViaGov(alice);

        devPool.registerDeveloper(dev1);
        devPool.registerDeveloper(dev2);
        nft.mint(dev1, 100, "ipfs://dev1");
        nft.mint(dev2, 100, "ipfs://dev2");
        karmaCore.setDeveloperGmv(dev1, 70);
        karmaCore.setDeveloperGmv(dev2, 30);

        usdc.mint(address(this), 1_000_000e6);
        usdc.approve(address(treasury), 1_000_000e6);
        treasury.notifyFee(1_000_000e6);
        vm.warp(block.timestamp + 7 days);
        treasury.performUpkeep("");

        vm.warp(block.timestamp + 30 days);
        devPool.settleEpoch();

        assertGt(devPool.claimableOf(dev1), devPool.claimableOf(dev2));
        uint256 c1 = devPool.claimableOf(dev1);
        vm.prank(dev1);
        devPool.claim();
        assertEq(usdc.balanceOf(dev1), c1);
    }

    function test_ClaimsDisabledWhenRevenueOff() public {
        address alice = makeAddr("alice");
        karma.transfer(alice, 1_000_000 ether);
        vm.startPrank(alice);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(1_000_000 ether, IMultiTierStake.Tier.Public);
        vm.expectRevert();
        stakerPool.claim();
        vm.stopPrank();
    }
}