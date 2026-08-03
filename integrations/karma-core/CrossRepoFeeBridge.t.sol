// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {KarmaBilateral} from "karma/core/KarmaBilateral.sol";
import {MockERC20} from "karma/test/mocks/MockERC20.sol";

import {SettlementMirror} from "economy/integration/SettlementMirror.sol";
import {FeeBridge} from "economy/integration/FeeBridge.sol";
import {Treasury} from "economy/treasury/Treasury.sol";
import {DeveloperRewardPool} from "economy/pools/DeveloperRewardPool.sol";
import {StakerRewardPool} from "economy/pools/StakerRewardPool.sol";
import {VerifierNodePool} from "economy/pools/VerifierNodePool.sol";
import {AutoBuyBurn} from "economy/pools/AutoBuyBurn.sol";
import {MultiTierStake} from "economy/staking/MultiTierStake.sol";
import {KarmaToken} from "economy/token/KarmaToken.sol";
import {ContributionNFT} from "economy/nft/ContributionNFT.sol";
import {KarmaGovernor} from "economy/governance/KarmaGovernor.sol";
import {MockUniswapRouter} from "economy/mocks/MockUniswapRouter.sol";
import {IMultiTierStake} from "economy/interfaces/IMultiTierStake.sol";

/// @notice Live AtoB101/Karma Bilateral x karma8 FeeBridge end-to-end linkage.
/// @dev Executed via integrations/karma-core/run_cross_repo_test.sh (not default forge test).
contract CrossRepoFeeBridgeTest is Test {
    KarmaBilateral internal bilateral;
    MockERC20 internal usdc;

    SettlementMirror internal mirror;
    FeeBridge internal bridge;
    Treasury internal treasury;
    MultiTierStake internal stake;
    KarmaToken internal karma;
    KarmaGovernor internal governor;
    DeveloperRewardPool internal devPool;

    address internal admin = makeAddr("admin");
    address internal buyer = makeAddr("buyer");
    address internal agent = makeAddr("agent");
    address internal alice = makeAddr("alice");

    uint256 internal constant BUYER_LOCK = 100_000_000; // 100 USDC
    uint256 internal constant AGENT_LOCK = 50_000_000; // 50 USDC
    bytes32 internal constant SCOPE = keccak256("cross-repo:linkage");
    bytes32 internal constant PROOF = keccak256("proof");

    function setUp() public {
        vm.startPrank(admin);
        bilateral = new KarmaBilateral(admin);
        usdc = new MockERC20();
        bilateral.setTokenAllowed(address(usdc), true);
        vm.stopPrank();

        karma = new KarmaToken(address(this));
        stake = new MultiTierStake(address(karma), address(this));
        ContributionNFT nft = new ContributionNFT(address(this));
        MockUniswapRouter router = new MockUniswapRouter();
        mirror = new SettlementMirror(address(this), address(0));

        devPool = new DeveloperRewardPool(address(usdc), address(this), address(mirror), address(nft));
        StakerRewardPool stakerPool = new StakerRewardPool(address(usdc), address(stake), address(this));
        VerifierNodePool verifierPool = new VerifierNodePool(address(usdc), address(stake), address(this));
        AutoBuyBurn buyBurn = new AutoBuyBurn(address(usdc), address(karma), address(this), address(router));

        treasury = new Treasury(
            address(usdc),
            address(this),
            address(devPool),
            address(stakerPool),
            address(verifierPool),
            address(buyBurn),
            address(bilateral)
        );
        bridge = new FeeBridge(address(usdc), address(treasury), address(mirror), address(stake), address(this));
        governor = new KarmaGovernor(address(stake), address(treasury), address(this));

        devPool.setTreasury(address(treasury));
        stakerPool.setTreasury(address(treasury));
        verifierPool.setTreasury(address(treasury));
        buyBurn.setTreasury(address(treasury));
        treasury.setGovernance(address(governor));
        stake.setGovernance(address(governor));

        bridge.setCore(address(bilateral));
        mirror.setReporter(address(bridge), true);
        vm.startPrank(admin);
        bilateral.setTreasury(address(treasury));
        bilateral.setFeeBridge(address(bridge));
        vm.stopPrank();

        usdc.mint(buyer, 1_000_000_000);
        usdc.mint(agent, 1_000_000_000);
        vm.prank(buyer);
        usdc.approve(address(bilateral), type(uint256).max);
        vm.prank(agent);
        usdc.approve(address(bilateral), type(uint256).max);

        karma.transfer(alice, 2_000_000 ether);
        vm.startPrank(alice);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(2_000_000 ether, IMultiTierStake.Tier.Public);
        vm.stopPrank();
    }

    function _bind() internal returns (uint256 bindingId) {
        vm.prank(buyer);
        uint256 bb = bilateral.lock(address(usdc), BUYER_LOCK);
        vm.prank(agent);
        uint256 ab = bilateral.lock(address(usdc), AGENT_LOCK);
        vm.prank(buyer);
        bindingId = bilateral.bind(bb, ab, SCOPE);
    }

    function _settle(uint256 bindingId) internal {
        vm.warp(block.timestamp + bilateral.disputeWindowSeconds() + 1);
        vm.prank(buyer);
        bilateral.settle(bindingId, PROOF);
        vm.warp(block.timestamp + bilateral.disputeWindow() + 1);
        bilateral.finalizeSettle(bindingId);
    }

    function test_Wiring_AddressesMatch() public view {
        assertEq(bilateral.treasury(), address(treasury));
        assertEq(bilateral.feeBridge(), address(bridge));
        assertEq(bridge.core(), address(bilateral));
        assertTrue(mirror.isReporter(address(bridge)));
    }

    function test_UnsetBridge_StillSettlesWithoutFee() public {
        vm.startPrank(admin);
        KarmaBilateral bare = new KarmaBilateral(admin);
        bare.setTokenAllowed(address(usdc), true);
        vm.stopPrank();

        vm.prank(buyer);
        usdc.approve(address(bare), type(uint256).max);
        vm.prank(agent);
        usdc.approve(address(bare), type(uint256).max);

        vm.prank(buyer);
        uint256 bb = bare.lock(address(usdc), BUYER_LOCK);
        vm.prank(agent);
        uint256 ab = bare.lock(address(usdc), AGENT_LOCK);
        vm.prank(buyer);
        uint256 id = bare.bind(bb, ab, SCOPE);

        uint256 buyerBefore = usdc.balanceOf(buyer);
        uint256 agentBefore = usdc.balanceOf(agent);

        vm.warp(block.timestamp + bare.disputeWindowSeconds() + 1);
        vm.prank(buyer);
        bare.settle(id, PROOF);
        vm.warp(block.timestamp + bare.disputeWindow() + 1);
        bare.finalizeSettle(id);

        assertEq(uint8(bare.getBinding(id).state), uint8(KarmaBilateral.BindingState.SETTLED));
        assertEq(usdc.balanceOf(buyer), buyerBefore + BUYER_LOCK);
        assertEq(usdc.balanceOf(agent), agentBefore + AGENT_LOCK);
    }

    function test_ColdStart_FreeSettle_MirrorsGmv() public {
        assertFalse(treasury.enableRevenueMode());
        assertEq(bridge.quoteFee(agent, BUYER_LOCK + AGENT_LOCK), 0);

        uint256 bindingId = _bind();
        uint256 buyerBefore = usdc.balanceOf(buyer);
        uint256 agentBefore = usdc.balanceOf(agent);
        _settle(bindingId);

        assertEq(usdc.balanceOf(buyer), buyerBefore + BUYER_LOCK);
        assertEq(usdc.balanceOf(agent), agentBefore + AGENT_LOCK);
        assertEq(usdc.balanceOf(address(treasury)), 0);

        bytes32 orderId = bytes32(bindingId);
        assertEq(mirror.getBillSnapshot(orderId).amountUsdc, BUYER_LOCK + AGENT_LOCK);
        assertEq(mirror.getBillSnapshot(orderId).feeUsdc, 0);
        assertEq(mirror.getBillSnapshot(orderId).buyer, buyer);
        assertEq(mirror.getBillSnapshot(orderId).seller, agent);
        assertEq(mirror.getBillSnapshot(orderId).developer, agent);
        assertEq(mirror.getDeveloperGmv(agent, 0, uint64(block.timestamp + 1)), BUYER_LOCK + AGENT_LOCK);
        assertEq(uint8(bilateral.getBinding(bindingId).state), uint8(KarmaBilateral.BindingState.SETTLED));
        assertTrue(bilateral.checkInvariant(address(usdc)));
    }

    function test_RevenueOn_CollectsFeeToTreasury() public {
        vm.prank(alice);
        uint256 proposalId = governor.proposeEnableRevenue(true, "enable");
        vm.prank(alice);
        governor.vote(proposalId, true);
        vm.warp(block.timestamp + 7 days + 1);
        governor.execute(proposalId);
        assertTrue(treasury.enableRevenueMode());

        uint256 total = BUYER_LOCK + AGENT_LOCK;
        uint256 expectedFee = (total * 20) / 10_000; // 0.2%
        assertEq(bridge.quoteFee(agent, total), expectedFee);
        assertGe(AGENT_LOCK, expectedFee);

        uint256 bindingId = _bind();
        uint256 buyerBefore = usdc.balanceOf(buyer);
        uint256 agentBefore = usdc.balanceOf(agent);
        _settle(bindingId);

        assertEq(usdc.balanceOf(buyer), buyerBefore + BUYER_LOCK);
        assertEq(usdc.balanceOf(agent), agentBefore + AGENT_LOCK - expectedFee);
        assertEq(usdc.balanceOf(address(treasury)), expectedFee);

        bytes32 orderId = bytes32(bindingId);
        assertEq(mirror.getBillSnapshot(orderId).feeUsdc, expectedFee);
        assertEq(mirror.getBillSnapshot(orderId).amountUsdc, total);
        assertEq(mirror.getDeveloperGmv(agent, 0, uint64(block.timestamp + 1)), total);
        assertTrue(bilateral.checkInvariant(address(usdc)));
    }
}
