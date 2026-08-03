// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {EconomyFixture} from "./helpers/EconomyFixture.sol";
import {SettlementMirror} from "../src/integration/SettlementMirror.sol";
import {FeeBridge} from "../src/integration/FeeBridge.sol";
import {ReferenceSettlementCore} from "../src/integration/ReferenceSettlementCore.sol";
import {CoreEscrowAdapter} from "../src/integration/CoreEscrowAdapter.sol";
import {IMultiTierStake} from "../src/interfaces/IMultiTierStake.sol";
import {BilateralFeeHook} from "../src/integration/BilateralFeeHook.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Minimal Bilateral-shaped settler that uses the same fee hook as the Karma patch.
contract MockBilateralWithFeeHook {
    using BilateralFeeHook for address;

    IERC20 public immutable usdc;
    address public feeBridge;
    address public admin;

    constructor(address usdc_, address feeBridge_, address admin_) {
        usdc = IERC20(usdc_);
        feeBridge = feeBridge_;
        admin = admin_;
    }

    function setFeeBridge(address b) external {
        require(msg.sender == admin, "auth");
        feeBridge = b;
    }

    function settle(bytes32 orderId, address buyer, address seller, address developer, uint256 amountUsdc) external {
        require(usdc.transferFrom(msg.sender, address(this), amountUsdc), "pull");
        uint256 fee = BilateralFeeHook.collectOnSettle(feeBridge, address(usdc), orderId, buyer, seller, developer, amountUsdc);
        uint256 payout = amountUsdc - fee;
        if (payout > 0) require(usdc.transfer(seller, payout), "payout");
    }
}

/// @notice Verifies karma8 bridge contracts satisfy the karma-core linkage contract.
contract CoreLinkageTest is EconomyFixture {
    SettlementMirror internal mirror;
    FeeBridge internal bridge;
    ReferenceSettlementCore internal core;
    CoreEscrowAdapter internal escrow;
    MockBilateralWithFeeHook internal bilateral;

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
        escrow = new CoreEscrowAdapter(address(mirror), address(this));
        bilateral = new MockBilateralWithFeeHook(address(usdc), address(bridge), address(this));

        bridge.setCore(address(bilateral));
        mirror.setReporter(address(bridge), true);
        mirror.setReporter(address(escrow), true);
        escrow.setArbitrator(address(arbitrator));
        escrow.setCoreTarget(address(core));
        core.setEscrowController(address(escrow));
        arbitrator.setKarmaCore(address(mirror));
        arbitrator.setCoreEscrowAdapter(address(escrow));
        vm.prank(address(treasury));
        devPool.setKarmaCore(address(mirror));

        usdc.mint(buyer, 5_000_000e6);
    }

    function test_BilateralFeeHook_FreeModeMirrorsGmv() public {
        bytes32 orderId = bytes32(uint256(42));
        vm.startPrank(buyer);
        usdc.approve(address(bilateral), 1_000_000e6);
        bilateral.settle(orderId, buyer, seller, developer, 1_000_000e6);
        vm.stopPrank();

        assertEq(usdc.balanceOf(seller), 1_000_000e6);
        assertEq(usdc.balanceOf(address(treasury)), 0);
        assertEq(mirror.getDeveloperGmv(developer, 0, uint64(block.timestamp + 1)), 1_000_000e6);
        assertEq(mirror.getBillSnapshot(orderId).feeUsdc, 0);
        assertEq(bridge.core(), address(bilateral));
    }

    function test_BilateralFeeHook_RevenueModeCollectsFee() public {
        address alice = makeAddr("alice");
        karma.transfer(alice, 2_000_000 ether);
        vm.startPrank(alice);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(2_000_000 ether, IMultiTierStake.Tier.Public);
        vm.stopPrank();
        _enableRevenueViaGov(alice);

        bytes32 orderId = bytes32(uint256(7));
        uint256 amount = 1_000_000e6;
        uint256 expectedFee = (amount * 20) / 10_000;

        vm.startPrank(buyer);
        usdc.approve(address(bilateral), amount);
        bilateral.settle(orderId, buyer, seller, developer, amount);
        vm.stopPrank();

        assertEq(usdc.balanceOf(seller), amount - expectedFee);
        assertEq(usdc.balanceOf(address(treasury)), expectedFee);
        assertEq(mirror.getBillSnapshot(orderId).feeUsdc, expectedFee);
        assertEq(mirror.getDeveloperGmv(developer, 0, uint64(block.timestamp + 1)), amount);
    }

    function test_EscrowAdapterForwardsToCoreTarget() public {
        bytes32 orderId = keccak256("escrow-1");
        vm.startPrank(buyer);
        usdc.approve(address(core), 100_000e6);
        core.openOrder(orderId, seller, developer, 100_000e6);
        vm.stopPrank();

        // Point bridge core at reference core for settle path used by open orders.
        bridge.setCore(address(core));

        vm.prank(address(arbitrator));
        escrow.freezeOrder(orderId);
        assertTrue(mirror.isOrderFrozen(orderId));
        (,,,, bool open, bool frozen) = core.orders(orderId);
        assertTrue(open);
        assertTrue(frozen);

        vm.expectRevert();
        vm.prank(buyer);
        core.settle(orderId);

        vm.prank(address(arbitrator));
        escrow.refundToBuyer(orderId);
        assertEq(usdc.balanceOf(buyer), 5_000_000e6); // full refund to original mint balance
        assertFalse(mirror.isOrderFrozen(orderId));
    }

    function test_ReadPathUsesMirrorNotLiveCoreStorage() public {
        bytes32 orderId = bytes32(uint256(99));
        vm.startPrank(buyer);
        usdc.approve(address(bilateral), 50_000e6);
        bilateral.settle(orderId, buyer, seller, developer, 50_000e6);
        vm.stopPrank();

        // Economy consumers must resolve snapshots via SettlementMirror.
        assertEq(address(devPool.karmaCore()), address(mirror));
        assertEq(address(arbitrator.karmaCore()), address(mirror));
        assertEq(arbitrator.karmaCore().getBillSnapshot(orderId).seller, seller);
    }
}
