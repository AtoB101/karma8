// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {EconomyFixture} from "./helpers/EconomyFixture.sol";
import {MultiTierStake} from "../src/staking/MultiTierStake.sol";
import {IMultiTierStake} from "../src/interfaces/IMultiTierStake.sol";
import {KarmaGovernor} from "../src/governance/KarmaGovernor.sol";

contract GovernanceTest is EconomyFixture {
    function setUp() public {
        setUpEconomy();
    }

    function test_CannotProposeFeeParamChange() public {
        address alice = makeAddr("alice");
        karma.transfer(alice, 1_000_000 ether);
        vm.startPrank(alice);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(1_000_000 ether, IMultiTierStake.Tier.Public);
        bytes memory data = abi.encodeWithSignature("setFeeBps(uint256)", 50);
        vm.expectRevert(KarmaGovernor.ForbiddenParam.selector);
        governor.proposeCustomCall(address(treasury), data, "evil fee");
        vm.stopPrank();
    }

    function test_EnableThenDisableRevenue() public {
        address alice = makeAddr("alice");
        karma.transfer(alice, 1_000_000 ether);
        vm.startPrank(alice);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(1_000_000 ether, IMultiTierStake.Tier.Public);
        vm.stopPrank();

        _enableRevenueViaGov(alice);
        assertTrue(treasury.enableRevenueMode());

        vm.prank(alice);
        uint256 id = governor.proposeEnableRevenue(false, "disable");
        vm.prank(alice);
        governor.vote(id, true);
        vm.warp(block.timestamp + 7 days + 1);
        governor.execute(id);
        assertFalse(treasury.enableRevenueMode());
    }
}