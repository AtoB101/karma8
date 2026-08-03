// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {KarmaToken} from "../../src/token/KarmaToken.sol";
import {MultiTierStake} from "../../src/staking/MultiTierStake.sol";
import {IMultiTierStake} from "../../src/interfaces/IMultiTierStake.sol";

contract StakeHandler is Test {
    MultiTierStake public stake;
    KarmaToken public karma;
    address[] public actors;
    uint256 public ghostStaked;

    constructor(MultiTierStake stake_, KarmaToken karma_, address[] memory actors_) {
        stake = stake_;
        karma = karma_;
        actors = actors_;
    }

    function stakePublic(uint256 actorIdx, uint256 amount) external {
        address a = actors[actorIdx % actors.length];
        amount = bound(amount, 1 ether, 100_000 ether);
        uint256 bal = karma.balanceOf(a);
        if (amount > bal) amount = bal;
        if (amount == 0) return;
        vm.prank(a);
        stake.stake(amount, IMultiTierStake.Tier.Public);
        ghostStaked += amount;
    }

    function unstake(uint256 actorIdx, uint256 amount) external {
        address a = actors[actorIdx % actors.length];
        uint256 st = stake.stakeOf(a);
        if (st == 0) return;
        amount = bound(amount, 1, st);
        vm.prank(a);
        try stake.unstake(amount) {
            ghostStaked -= amount;
        } catch {}
    }
}

contract StakingInvariantTest is Test {
    KarmaToken internal karma;
    MultiTierStake internal stake;
    StakeHandler internal handler;

    function setUp() public {
        karma = new KarmaToken(address(this));
        stake = new MultiTierStake(address(karma), address(this));

        address[] memory actors = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            actors[i] = makeAddr(string(abi.encodePacked("actor", vm.toString(i))));
            karma.transfer(actors[i], 10_000_000 ether);
            vm.prank(actors[i]);
            karma.approve(address(stake), type(uint256).max);
        }

        handler = new StakeHandler(stake, karma, actors);
        targetContract(address(handler));
    }

    function invariant_totalStakedMatchesGhost() public view {
        assertEq(stake.totalStaked(), handler.ghostStaked());
    }

    function invariant_contractBalanceCoversStake() public view {
        assertGe(karma.balanceOf(address(stake)), stake.totalStaked());
    }

    function invariant_weightNonNegative() public view {
        assertGe(stake.totalVotingWeight(), 0);
    }
}
