// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {EconomyFixture} from "./helpers/EconomyFixture.sol";
import {IMultiTierStake} from "../src/interfaces/IMultiTierStake.sol";
import {MultiSigWallet} from "../src/governance/MultiSigWallet.sol";
import {KarmaGovernor} from "../src/governance/KarmaGovernor.sol";
import {Treasury} from "../src/treasury/Treasury.sol";

contract SecurityHardeningTest is EconomyFixture {
    function setUp() public {
        setUpEconomy();
    }

    function test_ReentrancyClaimDoesNotDoublePay() public {
        address alice = makeAddr("alice");
        karma.transfer(alice, 1_000_000 ether);
        vm.startPrank(alice);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(1_000_000 ether, IMultiTierStake.Tier.Public);
        vm.stopPrank();
        _enableRevenueViaGov(alice);

        usdc.mint(address(this), 100_000e6);
        usdc.approve(address(treasury), 100_000e6);
        treasury.notifyFee(100_000e6);
        vm.warp(block.timestamp + 7 days);
        treasury.performUpkeep("");

        stakerPool.updateAccount(alice);
        uint256 e1 = stakerPool.earned(alice);
        vm.prank(alice);
        stakerPool.claim();
        assertEq(stakerPool.earned(alice), 0);
        vm.prank(alice);
        vm.expectRevert();
        stakerPool.claim();
        assertEq(usdc.balanceOf(alice), e1);
    }

    function test_GovernorForbidsFeeParamSelectors() public {
        address alice = makeAddr("alice");
        karma.transfer(alice, 1_000_000 ether);
        vm.startPrank(alice);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(1_000_000 ether, IMultiTierStake.Tier.Public);
        bytes memory data = abi.encodeWithSignature("setSplitRatios(uint256,uint256,uint256,uint256)", 1, 1, 1, 1);
        vm.expectRevert(KarmaGovernor.ForbiddenParam.selector);
        governor.proposeCustomCall(address(treasury), data, "evil");
        vm.stopPrank();
    }

    function test_MultiSigRequiresFiveOfSevenForStandard() public {
        address[7] memory owners = [o0, o1, o2, o3, o4, o5, o6];
        MultiSigWallet wallet = new MultiSigWallet(owners);
        vm.prank(o0);
        uint256 id = wallet.submitTransaction(address(0xBEEF), 0, "", MultiSigWallet.OpKind.Standard);
        // only 1 confirmation so far
        vm.prank(o1);
        wallet.confirmTransaction(id);
        vm.prank(o2);
        wallet.confirmTransaction(id);
        vm.prank(o3);
        wallet.confirmTransaction(id);
        // 4 confs < 5
        vm.prank(o0);
        vm.expectRevert(MultiSigWallet.ThresholdNotMet.selector);
        wallet.executeTransaction(id);

        vm.prank(o4);
        wallet.confirmTransaction(id);
        // 5/7 ok — call to empty account succeeds with empty data
        vm.prank(o0);
        wallet.executeTransaction(id);
    }

    function test_ControllerOpsNeedSevenOfSeven() public {
        address[7] memory owners = [o0, o1, o2, o3, o4, o5, o6];
        MultiSigWallet wallet = new MultiSigWallet(owners);
        bytes memory data = abi.encodeWithSignature("rotateOwner(uint256,address)", 0, makeAddr("new"));
        vm.prank(o0);
        uint256 id = wallet.submitTransaction(address(wallet), 0, data, MultiSigWallet.OpKind.Controller);
        for (uint256 i = 1; i < 6; i++) {
            vm.prank(owners[i]);
            wallet.confirmTransaction(id);
        }
        // 6/7
        vm.prank(o0);
        vm.expectRevert(MultiSigWallet.ThresholdNotMet.selector);
        wallet.executeTransaction(id);

        vm.prank(o6);
        wallet.confirmTransaction(id);
        vm.prank(o0);
        wallet.executeTransaction(id);
        assertTrue(wallet.isOwner(makeAddr("new")));
    }

    function test_CannotDistributeBeforeIntervalEvenIfRevenueOn() public {
        address alice = makeAddr("alice");
        karma.transfer(alice, 1_000_000 ether);
        vm.startPrank(alice);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(1_000_000 ether, IMultiTierStake.Tier.Public);
        vm.stopPrank();
        _enableRevenueViaGov(alice);

        // Governance warp may already satisfy the first weekly window — consume it.
        usdc.mint(address(this), 20_000e6);
        usdc.approve(address(treasury), 20_000e6);
        treasury.notifyFee(10_000e6);
        treasury.performUpkeep("");

        // Immediate second distribution must wait another week.
        treasury.notifyFee(10_000e6);
        vm.expectRevert(Treasury.TooEarly.selector);
        treasury.performUpkeep("");
    }
}
