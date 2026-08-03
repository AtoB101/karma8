// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {EconomyFixture} from "./helpers/EconomyFixture.sol";
import {MultiTierStake} from "../src/staking/MultiTierStake.sol";
import {IMultiTierStake} from "../src/interfaces/IMultiTierStake.sol";
import {KarmaEconomyConstants} from "../src/libraries/KarmaEconomyConstants.sol";

contract MultiTierStakeTest is EconomyFixture {
    address internal user;

    function setUp() public {
        setUpEconomy();
        user = makeAddr("user");
        karma.transfer(user, 10_000_000 ether);
        vm.prank(user);
        karma.approve(address(stake), type(uint256).max);
    }

    function test_PublicStakeAndDurationMultiplier() public {
        vm.prank(user);
        stake.stake(1000 ether, IMultiTierStake.Tier.Public);
        assertEq(uint8(stake.tierOf(user)), uint8(IMultiTierStake.Tier.Public));
        assertEq(stake.durationMultiplier(user), KarmaEconomyConstants.MULT_BASE);

        vm.warp(block.timestamp + 90 days);
        assertEq(stake.durationMultiplier(user), KarmaEconomyConstants.MULT_3M);

        vm.warp(block.timestamp + 275 days);
        assertEq(stake.durationMultiplier(user), KarmaEconomyConstants.MULT_12M);
        assertEq(stake.votingWeight(user), 1000 ether * 2);
    }

    function test_DurationResetsOnAdditionalStake() public {
        vm.prank(user);
        stake.stake(1000 ether, IMultiTierStake.Tier.Public);
        vm.warp(block.timestamp + 100 days);
        assertEq(stake.durationMultiplier(user), KarmaEconomyConstants.MULT_3M);

        vm.prank(user);
        stake.stake(100 ether, IMultiTierStake.Tier.Public);
        assertEq(stake.durationMultiplier(user), KarmaEconomyConstants.MULT_BASE);
    }

    function test_DeveloperLockAndFeeDiscount() public {
        vm.prank(user);
        stake.stake(100_000 ether, IMultiTierStake.Tier.Developer);
        assertEq(uint8(stake.tierOf(user)), uint8(IMultiTierStake.Tier.Developer));

        // revenue off => fee 0 (free mode)
        assertEq(stake.feeBpsFor(user), 0);

        // enable revenue via alice with stake
        address alice = makeAddr("aliceGov");
        karma.transfer(alice, 1_000_000 ether);
        vm.startPrank(alice);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(1_000_000 ether, IMultiTierStake.Tier.Public);
        vm.stopPrank();
        _enableRevenueViaGov(alice);

        assertEq(stake.feeBpsFor(user), 10);

        vm.prank(user);
        vm.expectRevert(MultiTierStake.Locked.selector);
        stake.unstake(1 ether);

        vm.warp(block.timestamp + 180 days);
        vm.prank(user);
        stake.unstake(100_000 ether);
        assertEq(stake.stakeOf(user), 0);
    }

    function test_VerifierAndPartnerTiers() public {
        vm.prank(user);
        stake.stake(500_000 ether, IMultiTierStake.Tier.Verifier);
        assertTrue(stake.isActiveVerifier(user));
        assertEq(stake.verifierCount(), 1);

        vm.prank(user);
        stake.stake(4_500_000 ether, IMultiTierStake.Tier.Partner);
        assertEq(uint8(stake.tierOf(user)), uint8(IMultiTierStake.Tier.Partner));
        assertEq(stake.feeBpsFor(user), 0); // revenue still off
    }

    function test_MassUnstake() public {
        address[5] memory users;
        for (uint256 i = 0; i < 5; i++) {
            users[i] = makeAddr(string(abi.encodePacked("u", i)));
            karma.transfer(users[i], 10_000 ether);
            vm.startPrank(users[i]);
            karma.approve(address(stake), type(uint256).max);
            stake.stake(10_000 ether, IMultiTierStake.Tier.Public);
            vm.stopPrank();
        }
        assertEq(stake.totalStaked(), 50_000 ether);

        for (uint256 i = 0; i < 5; i++) {
            vm.prank(users[i]);
            stake.unstake(10_000 ether);
        }
        assertEq(stake.totalStaked(), 0);
    }
}
