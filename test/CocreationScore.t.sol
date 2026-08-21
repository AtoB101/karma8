// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {EconomyFixture} from "./helpers/EconomyFixture.sol";
import {ContributorRegistry} from "../src/cocreation/ContributorRegistry.sol";
import {ContributionLedger} from "../src/cocreation/ContributionLedger.sol";
import {CocreationScoreView} from "../src/cocreation/CocreationScoreView.sol";
import {IContributorRegistry} from "../src/interfaces/IContributorRegistry.sol";
import {IKarmaCoreView} from "../src/interfaces/IKarmaCoreView.sol";
import {SettlementMirror} from "../src/integration/SettlementMirror.sol";
import {FeeBridge} from "../src/integration/FeeBridge.sol";
import {ReferenceSettlementCore} from "../src/integration/ReferenceSettlementCore.sol";
import {DeveloperRewardPool} from "../src/pools/DeveloperRewardPool.sol";
import {KarmaEconomyConstants} from "../src/libraries/KarmaEconomyConstants.sol";

/// @notice Cocreation Score v1 acceptance (§8) + economy wiring.
contract CocreationScoreTest is EconomyFixture {
    ContributorRegistry internal registry;
    ContributionLedger internal ledger;
    CocreationScoreView internal scoreView;
    SettlementMirror internal mirror;
    FeeBridge internal bridge;
    ReferenceSettlementCore internal core;

    address internal builder = makeAddr("builder");
    address internal expert = makeAddr("expert");
    address internal unbound = makeAddr("unbound");
    address internal buyer = makeAddr("buyer");
    address internal seller = makeAddr("seller");

    bytes32 internal trackDigital = keccak256("digital");
    bytes32 internal trackHighRisk = keccak256("high_risk");

    function setUp() public {
        setUpEconomy();

        registry = new ContributorRegistry(address(this));
        ledger = new ContributionLedger(address(registry), address(nft), address(this), address(this));
        scoreView = new CocreationScoreView(address(ledger), address(stake), address(this), address(this));
        nft.setMinter(address(ledger));

        vm.prank(address(treasury));
        devPool.setRegistry(address(registry));

        mirror = new SettlementMirror(address(this), address(0));
        bridge = new FeeBridge(address(usdc), address(treasury), address(mirror), address(stake), address(this));
        core = new ReferenceSettlementCore(address(usdc), address(bridge), address(this));
        bridge.setCore(address(core));
        mirror.setReporter(address(bridge), true);
        vm.prank(address(treasury));
        devPool.setKarmaCore(address(mirror));

        usdc.mint(buyer, 5_000_000e6);
    }

    function _registerBuilderExpert(address wallet) internal {
        IContributorRegistry.Role[] memory roles = new IContributorRegistry.Role[](2);
        roles[0] = IContributorRegistry.Role.BUILDER;
        roles[1] = IContributorRegistry.Role.EXPERT;
        bytes32[] memory tracks = new bytes32[](2);
        tracks[0] = trackDigital;
        tracks[1] = trackHighRisk;
        registry.registerFor(wallet, roles, tracks);
    }

    function _accepted(uint256 id) internal view returns (bool accepted) {
        (,,,,,,,,, accepted,,,) = ledger.events(id);
    }

    function test_DualRoleAccountsQueryable() public {
        _registerBuilderExpert(builder);
        assertTrue(registry.hasRole(builder, IContributorRegistry.Role.BUILDER));
        assertTrue(registry.hasRole(builder, IContributorRegistry.Role.EXPERT));
        assertTrue(registry.isActive(builder));
        assertEq(registry.tracksOf(builder).length, 2);
    }

    function test_UnboundCannotSubmitOrMintOrRegisterDev() public {
        vm.expectRevert(ContributionLedger.NotBound.selector);
        vm.prank(unbound);
        ledger.submit(
            ContributionLedger.EventCode.ADAPTER_SHIP,
            IContributorRegistry.Role.BUILDER,
            trackDigital,
            ContributionLedger.Quality.Accepted,
            "uri"
        );

        vm.expectRevert(DeveloperRewardPool.NotBuilder.selector);
        devPool.registerDeveloper(unbound);
    }

    function test_AcceptedOnlyQualityStoredAt070() public {
        _registerBuilderExpert(builder);
        vm.prank(builder);
        uint256 id = ledger.submit(
            ContributionLedger.EventCode.SCENE_SPEC,
            IContributorRegistry.Role.EXPERT,
            trackDigital,
            ContributionLedger.Quality.Accepted,
            "spec"
        );
        (,,,,, uint256 qBps,,,, bool accepted,,,) = ledger.events(id);
        assertEq(qBps, 7000);
        assertFalse(accepted);
        ledger.accept(id);
        assertEq(ledger.lifetimeAcceptedWeight(builder), (800 * 7000 * 10_000) / (10_000 * 10_000));
    }

    function test_HighRiskLiveRequiresSceneOwnerAccepter() public {
        _registerBuilderExpert(builder);
        address ops = makeAddr("ops");
        ledger.setAccepter(ops);

        vm.prank(builder);
        uint256 id = ledger.submit(
            ContributionLedger.EventCode.TEMPLATE_LIVE,
            IContributorRegistry.Role.BUILDER,
            trackHighRisk,
            ContributionLedger.Quality.TestnetLive,
            "live"
        );

        vm.prank(ops);
        vm.expectRevert(ContributionLedger.Unauthorized.selector);
        ledger.accept(id);

        ledger.accept(id);
        assertTrue(_accepted(id));
    }

    function test_MintRequiresThresholdAndIdentity() public {
        _registerBuilderExpert(builder);
        vm.prank(builder);
        uint256 id = ledger.submit(
            ContributionLedger.EventCode.SCENE_SPEC,
            IContributorRegistry.Role.EXPERT,
            trackDigital,
            ContributionLedger.Quality.Accepted,
            "spec"
        );
        ledger.accept(id);
        assertGe(ledger.pendingMintWeight(builder), KarmaEconomyConstants.MINT_THRESHOLD_WEIGHT);

        vm.prank(builder);
        uint256 tokenId = ledger.mintPending(builder, "ipfs://contrib");
        assertEq(tokenId, 1);
        assertEq(nft.totalWeightOf(builder), ledger.lifetimeAcceptedWeight(builder));
        assertEq(ledger.pendingMintWeight(builder), 0);
    }

    function test_BelowThresholdCannotMint() public {
        _registerBuilderExpert(builder);
        vm.prank(builder);
        uint256 id = ledger.submit(
            ContributionLedger.EventCode.SETTLE_OK,
            IContributorRegistry.Role.BUILDER,
            trackDigital,
            ContributionLedger.Quality.Accepted,
            "settle"
        );
        ledger.accept(id);
        assertLt(ledger.pendingMintWeight(builder), KarmaEconomyConstants.MINT_THRESHOLD_WEIGHT);
        vm.prank(builder);
        vm.expectRevert(ContributionLedger.BelowThreshold.selector);
        ledger.mintPending(builder, "uri");
    }

    function test_RevenueOffAccumulatesWeightAndPendingShare() public {
        assertFalse(treasury.enableRevenueMode());
        _registerBuilderExpert(builder);
        devPool.registerDeveloper(builder);

        vm.prank(builder);
        uint256 id = ledger.submit(
            ContributionLedger.EventCode.ADAPTER_SHIP,
            IContributorRegistry.Role.BUILDER,
            trackDigital,
            ContributionLedger.Quality.TestnetLive,
            "adapter"
        );
        ledger.accept(id);
        vm.prank(builder);
        ledger.mintPending(builder, "uri");
        assertGt(nft.totalWeightOf(builder), 0);

        vm.startPrank(buyer);
        usdc.approve(address(core), 1_000_000e6);
        bytes32 orderId = keccak256("o1");
        core.openOrder(orderId, seller, builder, 1_000_000e6);
        core.settle(orderId);
        vm.stopPrank();

        (uint256 share, uint256 gmv, uint256 w) = devPool.previewEpochShare(builder, 1_000_000e6);
        assertEq(gmv, 1_000_000e6);
        assertEq(w, nft.totalWeightOf(builder));
        assertEq(share, 1_000_000e6);

        vm.warp(uint256(devPool.epochEnd()) + 1);
        devPool.settlePendingEpoch();
        assertGt(devPool.pendingPoints(builder), 0);
        assertGt(devPool.totalPendingPoints(), 0);
    }

    function test_PreviewMatches70_30Constants() public {
        _registerBuilderExpert(builder);
        address builder2 = makeAddr("builder2");
        _registerBuilderExpert(builder2);
        devPool.registerDeveloper(builder);
        devPool.registerDeveloper(builder2);

        for (uint256 i = 0; i < 2; i++) {
            address w = i == 0 ? builder : builder2;
            vm.prank(w);
            uint256 id = ledger.submit(
                ContributionLedger.EventCode.AUDIT_PASS,
                IContributorRegistry.Role.BUILDER,
                trackDigital,
                ContributionLedger.Quality.Accepted,
                "a"
            );
            ledger.accept(id);
            vm.prank(w);
            ledger.mintPending(w, "u");
        }

        vm.startPrank(buyer);
        usdc.approve(address(core), 1_000_000e6);
        core.openOrder(keccak256("g1"), seller, builder, 1_000_000e6);
        core.settle(keccak256("g1"));
        vm.stopPrank();

        uint256 reward = 1_000_000e6;
        (uint256 share1,,) = devPool.previewEpochShare(builder, reward);
        (uint256 share2,,) = devPool.previewEpochShare(builder2, reward);

        assertEq(share1, (reward * 85) / 100);
        assertEq(share2, (reward * 15) / 100);
        assertEq(devPool.GMV_WEIGHT_BPS(), 7000);
        assertEq(devPool.NFT_WEIGHT_BPS(), 3000);
    }

    function test_NegativeEventLowersOnlySubjectScore() public {
        _registerBuilderExpert(builder);
        _registerBuilderExpert(expert);

        vm.prank(builder);
        uint256 good = ledger.submit(
            ContributionLedger.EventCode.SCENE_SPEC,
            IContributorRegistry.Role.EXPERT,
            trackDigital,
            ContributionLedger.Quality.Accepted,
            "good"
        );
        ledger.accept(good);

        vm.prank(expert);
        uint256 good2 = ledger.submit(
            ContributionLedger.EventCode.SCENE_SPEC,
            IContributorRegistry.Role.EXPERT,
            trackDigital,
            ContributionLedger.Quality.Accepted,
            "good2"
        );
        ledger.accept(good2);

        uint256 beforeB = ledger.activeContribution(builder);
        uint256 beforeE = ledger.activeContribution(expert);

        vm.prank(builder);
        uint256 bad = ledger.submit(
            ContributionLedger.EventCode.NEGATIVE_FRAUD,
            IContributorRegistry.Role.BUILDER,
            trackDigital,
            ContributionLedger.Quality.Accepted,
            "fraud"
        );
        ledger.accept(bad);

        assertLt(ledger.activeContribution(builder), beforeB);
        assertEq(ledger.activeContribution(expert), beforeE);

        scoreView.setSettleRep(builder, 5000);
        scoreView.setSettleRep(expert, 5000);
        (uint256 sb,,,) = scoreView.scoreExpert(builder);
        (uint256 se,,,) = scoreView.scoreExpert(expert);
        assertLt(sb, se);
    }

    function test_SelfDealDoesNotCreditDeveloperGmv() public {
        mirror.setReporter(address(this), true);
        IKarmaCoreView.BillSnapshot memory bill = IKarmaCoreView.BillSnapshot({
            orderId: keccak256("wash"),
            buyer: buyer,
            seller: buyer,
            developer: builder,
            amountUsdc: 999_000e6,
            feeUsdc: 0,
            settledAt: uint64(block.timestamp),
            disputed: false,
            frozen: false
        });
        mirror.recordBill(bill);
        assertEq(mirror.getDeveloperGmv(builder, 0, uint64(block.timestamp + 1)), 0);
        assertEq(mirror.getBillSnapshot(keccak256("wash")).amountUsdc, 999_000e6);
    }

    function test_DecayWindows() public {
        _registerBuilderExpert(builder);
        vm.prank(builder);
        uint256 id = ledger.submit(
            ContributionLedger.EventCode.ADAPTER_SHIP,
            IContributorRegistry.Role.BUILDER,
            trackDigital,
            ContributionLedger.Quality.TestnetLive,
            "a"
        );
        ledger.accept(id);
        assertEq(ledger.activeContribution(builder), 500);

        vm.warp(block.timestamp + 91 days);
        assertEq(ledger.activeContribution(builder), 250);

        vm.warp(block.timestamp + 300 days);
        assertEq(ledger.activeContribution(builder), 100);
    }

    function test_ScoreMixBuilderExpert() public {
        _registerBuilderExpert(builder);
        vm.prank(builder);
        uint256 id = ledger.submit(
            ContributionLedger.EventCode.AUDIT_PASS,
            IContributorRegistry.Role.BUILDER,
            trackDigital,
            ContributionLedger.Quality.ProdGmv,
            "audit"
        );
        ledger.accept(id);
        scoreView.setSettleRep(builder, 8000);

        (uint256 sb, uint256 rS, uint256 rC,) = scoreView.scoreBuilder(builder);
        (uint256 se,,,) = scoreView.scoreExpert(builder);
        assertEq(rS, 8000);
        assertGt(rC, 0);
        assertGt(sb, 0);
        assertGt(se, 0);
        assertTrue(sb != se);
    }
}
