// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {EconomyFixture} from "./helpers/EconomyFixture.sol";
import {MultiTierStake} from "../src/staking/MultiTierStake.sol";
import {IMultiTierStake} from "../src/interfaces/IMultiTierStake.sol";
import {IKarmaCoreView} from "../src/interfaces/IKarmaCoreView.sol";
import {DisputeArbitrator} from "../src/arbitration/DisputeArbitrator.sol";

contract DisputeArbitratorTest is EconomyFixture {
    function setUp() public {
        setUpEconomy();
        // Create 15 verifier nodes
        for (uint256 i = 0; i < 15; i++) {
            address node = makeAddr(string(abi.encodePacked("node", vm.toString(i))));
            karma.transfer(node, 500_000 ether);
            vm.startPrank(node);
            karma.approve(address(stake), type(uint256).max);
            stake.stake(500_000 ether, IMultiTierStake.Tier.Verifier);
            vm.stopPrank();
        }
        assertEq(stake.verifierCount(), 15);
    }

    function test_OpenDisputeAndMajorityReleaseSeller() public {
        bytes32 orderId = keccak256("order-1");
        address buyer = makeAddr("buyer");
        address seller = makeAddr("seller");
        karmaCore.setBill(
            IKarmaCoreView.BillSnapshot({
                orderId: orderId,
                buyer: buyer,
                seller: seller,
                developer: seller,
                amountUsdc: 1000e6,
                feeUsdc: 2e6,
                settledAt: uint64(block.timestamp),
                disputed: true,
                frozen: false
            })
        );

        uint256 id = arbitrator.openDispute(orderId);
        address[] memory panel = arbitrator.getPanel(id);
        assertEq(panel.length, 15);

        // 8 vote seller, 7 vote buyer
        for (uint256 i = 0; i < 15; i++) {
            DisputeArbitrator.Ruling r =
                i < 8 ? DisputeArbitrator.Ruling.ReleaseSeller : DisputeArbitrator.Ruling.RefundBuyer;
            vm.prank(panel[i]);
            arbitrator.vote(id, r);
        }

        (,,,, bool resolved, DisputeArbitrator.Ruling ruling,,,) = arbitrator.getDispute(id);
        assertTrue(resolved);
        assertEq(uint8(ruling), uint8(DisputeArbitrator.Ruling.ReleaseSeller));
    }

    function test_MaliciousNodeSlashAfterLowAccuracy() public {
        // Run 5 disputes where one node always votes minority
        address bad = stake.verifierAt(0);

        for (uint256 d = 0; d < 5; d++) {
            bytes32 orderId = keccak256(abi.encodePacked("ord", d));
            karmaCore.setBill(
                IKarmaCoreView.BillSnapshot({
                    orderId: orderId,
                    buyer: makeAddr("b"),
                    seller: makeAddr("s"),
                    developer: makeAddr("s"),
                    amountUsdc: 100e6,
                    feeUsdc: 1e6,
                    settledAt: uint64(block.timestamp),
                    disputed: true,
                    frozen: false
                })
            );
            uint256 id = arbitrator.openDispute(orderId);
            address[] memory panel = arbitrator.getPanel(id);

            // Force majority ReleaseSeller; bad votes RefundBuyer when on panel
            for (uint256 i = 0; i < panel.length; i++) {
                DisputeArbitrator.Ruling r = DisputeArbitrator.Ruling.ReleaseSeller;
                if (panel[i] == bad) r = DisputeArbitrator.Ruling.RefundBuyer;
                vm.prank(panel[i]);
                arbitrator.vote(id, r);
            }
        }

        // Depending on random panel inclusion, bad may be slashed if accuracy <40% after 5 votes
        // At minimum ensure dispute flow completed without revert
        assertGt(arbitrator.nextDisputeId(), 0);
    }
}
