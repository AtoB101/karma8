// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {EconomyFixture} from "./helpers/EconomyFixture.sol";
import {SettlementMirror} from "../src/integration/SettlementMirror.sol";
import {FeeBridge} from "../src/integration/FeeBridge.sol";
import {ReferenceSettlementCore} from "../src/integration/ReferenceSettlementCore.sol";
import {IKarmaCoreView} from "../src/interfaces/IKarmaCoreView.sol";
import {MultiSigWallet} from "../src/governance/MultiSigWallet.sol";
import {KarmaGovernor} from "../src/governance/KarmaGovernor.sol";
import {IMultiTierStake} from "../src/interfaces/IMultiTierStake.sol";

/// @notice Regression coverage for SECURITY_AUDIT_2026-08-21 Critical/High remediations.
contract SecurityAuditRegressionTest is EconomyFixture {
    SettlementMirror internal mirror;
    FeeBridge internal bridge;
    ReferenceSettlementCore internal core;

    address internal buyer;
    address internal seller;
    address internal developer;

    function setUp() public {
        setUpEconomy();
        buyer = makeAddr("buyer");
        seller = makeAddr("seller");
        developer = makeAddr("developer");

        mirror = new SettlementMirror(address(this), address(0));
        bridge = new FeeBridge(address(usdc), address(treasury), address(mirror), address(stake), address(this));
        core = new ReferenceSettlementCore(address(usdc), address(bridge), address(this));
        bridge.setCore(address(core));
        mirror.setReporter(address(bridge), true);
        treasury.setKarmaCore(address(core));

        usdc.mint(buyer, 10_000_000e6);
    }

    function test_MirrorRejectsOrderIdReplayGmvInflation() public {
        mirror.setReporter(address(this), true);
        IKarmaCoreView.BillSnapshot memory bill = IKarmaCoreView.BillSnapshot({
            orderId: keccak256("once"),
            buyer: buyer,
            seller: seller,
            developer: developer,
            amountUsdc: 1_000e6,
            feeUsdc: 0,
            settledAt: uint64(block.timestamp),
            disputed: false,
            frozen: false
        });
        mirror.recordBill(bill);
        assertEq(mirror.lifetimeDeveloperGmv(developer), 1_000e6);
        vm.expectRevert(bytes("exists"));
        mirror.recordBill(bill);
        assertEq(mirror.lifetimeDeveloperGmv(developer), 1_000e6);
    }

    function test_FeeBridgeRejectsUnderquotedFeeWhenRevenueOn() public {
        address alice = makeAddr("alice");
        karma.transfer(alice, 2_000_000 ether);
        vm.startPrank(alice);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(2_000_000 ether, IMultiTierStake.Tier.Public);
        vm.stopPrank();
        _enableRevenueViaGov(alice);

        uint256 amount = 1_000_000e6;
        uint256 expected = bridge.quoteFee(developer, amount);
        assertGt(expected, 0);

        bytes32 orderId = keccak256("underfee");
        vm.startPrank(buyer);
        usdc.approve(address(core), amount);
        core.openOrder(orderId, seller, developer, amount);
        // Direct collectAndRecord with fee=0 while revenue on must fail FeeMismatch
        // (settle path uses quoteFee — also cannot underpay via custom core)
        vm.stopPrank();

        // Impersonate core: fee 0 while expected > 0
        vm.prank(address(core));
        vm.expectRevert(FeeBridge.FeeMismatch.selector);
        bridge.collectAndRecord(orderId, buyer, seller, developer, amount, 0);
    }

    function test_MultiSigStandardCannotRotateOwner() public {
        address[7] memory owners = [o0, o1, o2, o3, o4, o5, o6];
        MultiSigWallet wallet = new MultiSigWallet(owners);
        bytes memory data = abi.encodeWithSignature("rotateOwner(uint256,address)", 0, makeAddr("new"));
        vm.prank(o0);
        uint256 id = wallet.submitTransaction(address(wallet), 0, data, MultiSigWallet.OpKind.Standard);
        for (uint256 i = 1; i < 5; i++) {
            vm.prank(owners[i]);
            wallet.confirmTransaction(id);
        }
        // 5/7 would have been enough for Standard before fix; self-call now needs 7/7
        vm.prank(o0);
        vm.expectRevert(MultiSigWallet.ThresholdNotMet.selector);
        wallet.executeTransaction(id);
    }

    function test_GovernorRejectsDangerousCustomCallSelectors() public {
        address alice = makeAddr("alice");
        karma.transfer(alice, 2_000_000 ether);
        vm.startPrank(alice);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(2_000_000 ether, IMultiTierStake.Tier.Public);
        bytes memory data = abi.encodeWithSignature("setCore(address)", makeAddr("evil"));
        vm.expectRevert(KarmaGovernor.ForbiddenParam.selector);
        governor.proposeCustomCall(address(bridge), data, "evil core");
        vm.stopPrank();
    }

    function test_GovernorRequiresParticipationQuorum() public {
        address whale = makeAddr("whale");
        address minnow = makeAddr("minnow");
        karma.transfer(whale, 9_000_000 ether);
        karma.transfer(minnow, 100_000 ether);
        vm.startPrank(whale);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(9_000_000 ether, IMultiTierStake.Tier.Public);
        vm.stopPrank();
        vm.startPrank(minnow);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(100_000 ether, IMultiTierStake.Tier.Public);
        uint256 id = governor.proposeEnableRevenue(true, "tiny");
        governor.vote(id, true);
        vm.stopPrank();
        // minnow alone ~1.1% < 10% participation
        vm.warp(block.timestamp + 7 days + 1);
        vm.expectRevert(KarmaGovernor.NotSucceeded.selector);
        governor.execute(id);
    }
}
