// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {EconomyFixture} from "./helpers/EconomyFixture.sol";
import {SettlementMirror} from "../src/integration/SettlementMirror.sol";
import {FeeBridge} from "../src/integration/FeeBridge.sol";
import {ReferenceSettlementCore} from "../src/integration/ReferenceSettlementCore.sol";
import {CoreEscrowAdapter} from "../src/integration/CoreEscrowAdapter.sol";
import {IMultiTierStake} from "../src/interfaces/IMultiTierStake.sol";
import {KarmaEconomyConstants} from "../src/libraries/KarmaEconomyConstants.sol";
import {MultiSigWallet} from "../src/governance/MultiSigWallet.sol";
import {AutoBuyBurn} from "../src/pools/AutoBuyBurn.sol";
import {KarmaVesting} from "../src/token/KarmaVesting.sol";

/// @notice Go-live acceptance gate targeting >=95% commercial readiness in-repo.
contract GoLiveAcceptanceTest is EconomyFixture {
    SettlementMirror internal mirror;
    FeeBridge internal bridge;
    ReferenceSettlementCore internal core;

    address internal buyer = makeAddr("buyer");
    address internal seller = makeAddr("seller");
    address internal developer = makeAddr("developer");
    address internal alice = makeAddr("alice");

    uint256 internal constant CHECKS = 12;
    bool[CHECKS] internal passed;

    function setUp() public {
        setUpEconomy();
        mirror = new SettlementMirror(address(this), address(0));
        bridge = new FeeBridge(address(usdc), address(treasury), address(mirror), address(stake), address(this));
        core = new ReferenceSettlementCore(address(usdc), address(bridge), address(this));
        CoreEscrowAdapter escrow = new CoreEscrowAdapter(address(mirror), address(this));

        bridge.setCore(address(core));
        mirror.setReporter(address(bridge), true);
        mirror.setReporter(address(escrow), true);
        escrow.setArbitrator(address(arbitrator));
        arbitrator.setKarmaCore(address(mirror));
        arbitrator.setCoreEscrowAdapter(address(escrow));
        treasury.setKarmaCore(address(core));
        vm.prank(address(treasury));
        devPool.setKarmaCore(address(mirror));

        karma.transfer(alice, 5_000_000 ether);
        vm.startPrank(alice);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(2_000_000 ether, IMultiTierStake.Tier.Public);
        vm.stopPrank();
        usdc.mint(buyer, 20_000_000e6);
    }

    function test_GoLiveAcceptance95() public {
        // 1) Immutable economics
        passed[0] = treasury.feeBps() == 20;
        (uint256 a, uint256 b, uint256 c, uint256 d) = treasury.splitRatios();
        passed[1] = (a == 40 && b == 30 && c == 20 && d == 10 && a + b + c + d == 100);

        // 2) Safe defaults
        passed[2] = treasury.enableRevenueMode() == false && buyBurn.swapPaused() == true;

        // 3) Private transfer blocked
        try treasury.transfer(address(0xBEEF), 1) {
            passed[3] = false;
        } catch {
            passed[3] = true;
        }

        // 4) Cold-start free settle + GMV mirror
        bytes32 o1 = keccak256("acc-free");
        vm.startPrank(buyer);
        usdc.approve(address(core), 2_000_000e6);
        core.openOrder(o1, seller, developer, 2_000_000e6);
        core.settle(o1);
        vm.stopPrank();
        passed[4] = usdc.balanceOf(address(treasury)) == 0
            && mirror.getDeveloperGmv(developer, 0, uint64(block.timestamp + 1)) == 2_000_000e6;

        // 5) Governance can enable revenue
        _enableRevenueViaGov(alice);
        passed[5] = treasury.enableRevenueMode() && stake.revenueMode();

        // 6) Developer discount 0.1%
        karma.transfer(developer, 100_000 ether);
        vm.startPrank(developer);
        karma.approve(address(stake), type(uint256).max);
        stake.stake(100_000 ether, IMultiTierStake.Tier.Developer);
        vm.stopPrank();
        passed[6] = bridge.quoteFeeBps(developer) == KarmaEconomyConstants.DEVELOPER_FEE_BPS;

        // 7) Fee settle + weekly split exactness
        bytes32 o2 = keccak256("acc-paid");
        uint256 amount = 1_000_000e6;
        uint256 fee = bridge.quoteFee(developer, amount);
        vm.startPrank(buyer);
        usdc.approve(address(core), amount);
        core.openOrder(o2, seller, developer, amount);
        core.settle(o2);
        vm.stopPrank();
        vm.warp(block.timestamp + 7 days);
        treasury.performUpkeep("");
        passed[7] = usdc.balanceOf(address(devPool)) == (fee * 40) / 100
            && usdc.balanceOf(address(stakerPool)) == (fee * 30) / 100
            && usdc.balanceOf(address(verifierPool)) == (fee * 20) / 100
            && usdc.balanceOf(address(buyBurn)) == (fee * 10) / 100;

        // 8) Staker claim works under revenue mode
        stakerPool.updateAccount(alice);
        uint256 earned = stakerPool.earned(alice);
        uint256 before = usdc.balanceOf(alice);
        vm.prank(alice);
        stakerPool.claim();
        passed[8] = earned > 0 && usdc.balanceOf(alice) == before + earned;

        // 9) Buyburn can execute after controller unpauses (mainnet posture rehearsal)
        vm.prank(address(treasury));
        buyBurn.setSwapPaused(false);
        uint256 burnBal = usdc.balanceOf(address(buyBurn));
        if (burnBal > 0) {
            buyBurn.executeBuyBurn(burnBal, 0);
            passed[9] = buyBurn.totalKarmaBurned() > 0;
        } else {
            passed[9] = false;
        }
        // re-pause for testnet safety posture
        vm.prank(address(treasury));
        buyBurn.setSwapPaused(true);

        // 10) Multisig thresholds encoded
        passed[10] = KarmaEconomyConstants.MULTISIG_EXEC_THRESHOLD == 5
            && KarmaEconomyConstants.MULTISIG_CONTROLLER_THRESHOLD == 7;

        // 11) Vesting grant path
        uint256 grantAmt = 1_000 ether;
        karma.transfer(address(vesting), grantAmt);
        uint256 gid = vesting.createGrant(KarmaVesting.Category.Tge, alice, grantAmt, uint64(block.timestamp));
        uint256 claimable = vesting.claimable(gid);
        passed[11] = claimable > 0; // TGE immediate 8/15

        // Aggregate
        uint256 okCount;
        for (uint256 i = 0; i < CHECKS; i++) {
            if (passed[i]) okCount++;
        }
        uint256 pct = (okCount * 100) / CHECKS;
        assertGe(pct, 95, "go-live acceptance < 95%");
        assertEq(okCount, CHECKS, "all acceptance checks must pass");
    }
}
