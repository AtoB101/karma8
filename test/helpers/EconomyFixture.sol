// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {KarmaToken} from "../../src/token/KarmaToken.sol";
import {KarmaVesting} from "../../src/token/KarmaVesting.sol";
import {MultiSigWallet} from "../../src/governance/MultiSigWallet.sol";
import {KarmaGovernor} from "../../src/governance/KarmaGovernor.sol";
import {MultiTierStake} from "../../src/staking/MultiTierStake.sol";
import {ContributionNFT} from "../../src/nft/ContributionNFT.sol";
import {Treasury} from "../../src/treasury/Treasury.sol";
import {DeveloperRewardPool} from "../../src/pools/DeveloperRewardPool.sol";
import {StakerRewardPool} from "../../src/pools/StakerRewardPool.sol";
import {VerifierNodePool} from "../../src/pools/VerifierNodePool.sol";
import {AutoBuyBurn} from "../../src/pools/AutoBuyBurn.sol";
import {DisputeArbitrator} from "../../src/arbitration/DisputeArbitrator.sol";
import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {MockKarmaCore} from "../../src/mocks/MockKarmaCore.sol";
import {MockUniswapRouter} from "../../src/mocks/MockUniswapRouter.sol";

contract EconomyFixture is Test {
    address internal o0 = makeAddr("o0");
    address internal o1 = makeAddr("o1");
    address internal o2 = makeAddr("o2");
    address internal o3 = makeAddr("o3");
    address internal o4 = makeAddr("o4");
    address internal o5 = makeAddr("o5");
    address internal o6 = makeAddr("o6");

    MultiSigWallet internal msig;
    KarmaToken internal karma;
    MockUSDC internal usdc;
    MockKarmaCore internal karmaCore;
    MockUniswapRouter internal router;
    MultiTierStake internal stake;
    ContributionNFT internal nft;
    KarmaVesting internal vesting;
    Treasury internal treasury;
    DeveloperRewardPool internal devPool;
    StakerRewardPool internal stakerPool;
    VerifierNodePool internal verifierPool;
    AutoBuyBurn internal buyBurn;
    DisputeArbitrator internal arbitrator;
    KarmaGovernor internal governor;

    function setUpEconomy() internal {
        address[7] memory owners = [o0, o1, o2, o3, o4, o5, o6];
        msig = new MultiSigWallet(owners);
        usdc = new MockUSDC();
        karmaCore = new MockKarmaCore();
        router = new MockUniswapRouter();
        karma = new KarmaToken(address(this));
        stake = new MultiTierStake(address(karma), address(this));
        nft = new ContributionNFT(address(this));
        vesting = new KarmaVesting(address(karma), address(this));

        devPool = new DeveloperRewardPool(address(usdc), address(this), address(karmaCore), address(nft));
        stakerPool = new StakerRewardPool(address(usdc), address(stake), address(this));
        verifierPool = new VerifierNodePool(address(usdc), address(stake), address(this));
        buyBurn = new AutoBuyBurn(address(usdc), address(karma), address(this), address(router));

        treasury = new Treasury(
            address(usdc),
            address(this),
            address(devPool),
            address(stakerPool),
            address(verifierPool),
            address(buyBurn),
            address(karmaCore)
        );

        arbitrator = new DisputeArbitrator(address(stake), address(this), address(karmaCore));
        governor = new KarmaGovernor(address(stake), address(treasury), address(this));

        // Wire while fixture still controls pool treasury roles
        verifierPool.setArbitrator(address(arbitrator));
        stake.setArbitrator(address(arbitrator));
        arbitrator.setNodePool(address(verifierPool));
        vesting.setStake(address(stake));

        devPool.setTreasury(address(treasury));
        stakerPool.setTreasury(address(treasury));
        verifierPool.setTreasury(address(treasury));
        buyBurn.setTreasury(address(treasury));

        // Hand governance control to Governor last
        treasury.setGovernance(address(governor));
        stake.setGovernance(address(governor));

        // Seed router with KARMA for buyback tests
        karma.transfer(address(router), 50_000_000 ether);
    }

    function _enableRevenueViaGov(address proposer) internal {
        vm.prank(proposer);
        uint256 id = governor.proposeEnableRevenue(true, "enable revenue");
        vm.prank(proposer);
        governor.vote(id, true);
        vm.warp(block.timestamp + 7 days + 1);
        governor.execute(id);
    }
}