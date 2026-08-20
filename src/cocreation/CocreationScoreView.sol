// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ContributionLedger} from "./ContributionLedger.sol";
import {IMultiTierStake} from "../interfaces/IMultiTierStake.sol";
import {CocreationMath} from "../libraries/CocreationMath.sol";
import {KarmaEconomyConstants} from "../libraries/KarmaEconomyConstants.sol";

/// @title CocreationScoreView
/// @notice Composite Score for BUILDER / EXPERT: mix(R_settle, R_contrib, R_stake).
contract CocreationScoreView {
    ContributionLedger public ledger;
    IMultiTierStake public stake;
    address public governance;
    address public settleOracle;

    mapping(address => uint256) public settleRep; // 0..10000, fed by Karma ScoringEngine / off-chain

    event GovernanceUpdated(address indexed governance);
    event SettleOracleUpdated(address indexed oracle);
    event SettleRepUpdated(address indexed wallet, uint256 score);

    error Unauthorized();

    modifier onlyGovernance() {
        if (msg.sender != governance) revert Unauthorized();
        _;
    }

    modifier onlyOracle() {
        if (msg.sender != settleOracle && msg.sender != governance) revert Unauthorized();
        _;
    }

    constructor(address ledger_, address stake_, address governance_, address settleOracle_) {
        require(ledger_ != address(0) && governance_ != address(0), "zero");
        ledger = ContributionLedger(ledger_);
        stake = IMultiTierStake(stake_);
        governance = governance_;
        settleOracle = settleOracle_ == address(0) ? governance_ : settleOracle_;
    }

    function setGovernance(address g) external onlyGovernance {
        require(g != address(0), "zero");
        governance = g;
        emit GovernanceUpdated(g);
    }

    function setSettleOracle(address o) external onlyGovernance {
        require(o != address(0), "zero");
        settleOracle = o;
        emit SettleOracleUpdated(o);
    }

    function setLedger(address ledger_) external onlyGovernance {
        require(ledger_ != address(0), "zero");
        ledger = ContributionLedger(ledger_);
    }

    function setStake(address stake_) external onlyGovernance {
        stake = IMultiTierStake(stake_);
    }

    function setSettleRep(address wallet, uint256 score) external onlyOracle {
        require(score <= 10_000, "score");
        settleRep[wallet] = score;
        emit SettleRepUpdated(wallet, score);
    }

    function rContribOf(address wallet) public view returns (uint256) {
        return CocreationMath.rContrib(ledger.activeContribution(wallet));
    }

    function rStakeOf(address wallet) public view returns (uint256) {
        if (address(stake) == address(0)) return 0;
        try stake.tierOf(wallet) returns (IMultiTierStake.Tier t) {
            if (t == IMultiTierStake.Tier.None) return 0;
            if (t == IMultiTierStake.Tier.Public) return 2500;
            if (t == IMultiTierStake.Tier.Developer) return 5000;
            if (t == IMultiTierStake.Tier.Verifier) return 7500;
            if (t == IMultiTierStake.Tier.Partner) return 10_000;
        } catch {}
        return 0;
    }

    function scoreBuilder(address wallet) external view returns (uint256 score, uint256 rS, uint256 rC, uint256 rK) {
        rS = settleRep[wallet];
        rC = rContribOf(wallet);
        rK = rStakeOf(wallet);
        score =
            (rS
                    * KarmaEconomyConstants.BUILDER_SETTLE_MIX_BPS
                    + rC
                    * KarmaEconomyConstants.BUILDER_CONTRIB_MIX_BPS
                    + rK
                    * KarmaEconomyConstants.BUILDER_STAKE_MIX_BPS) / 10_000;
    }

    function scoreExpert(address wallet) external view returns (uint256 score, uint256 rS, uint256 rC, uint256 rK) {
        rS = settleRep[wallet];
        rC = rContribOf(wallet);
        rK = rStakeOf(wallet);
        score =
            (rS
                    * KarmaEconomyConstants.EXPERT_SETTLE_MIX_BPS
                    + rC
                    * KarmaEconomyConstants.EXPERT_CONTRIB_MIX_BPS
                    + rK
                    * KarmaEconomyConstants.EXPERT_STAKE_MIX_BPS) / 10_000;
    }
}
