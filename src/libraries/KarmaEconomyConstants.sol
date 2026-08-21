// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title KarmaEconomyConstants
/// @notice Immutable economic parameters. Once deployed, fee/split ratios MUST NEVER be mutable.
library KarmaEconomyConstants {
    /// @dev Protocol fee: 0.2% = 20 bps
    uint256 internal constant FEE_BPS = 20;
    uint256 internal constant BPS_DENOMINATOR = 10_000;

    /// @dev Reduced fee for Tier-2 developers: 0.1% = 10 bps
    uint256 internal constant DEVELOPER_FEE_BPS = 10;

    /// @dev Treasury split ratios (must sum to 100)
    uint256 internal constant DEVELOPER_POOL_PCT = 40;
    uint256 internal constant STAKER_POOL_PCT = 30;
    uint256 internal constant VERIFIER_POOL_PCT = 20;
    uint256 internal constant BUYBURN_POOL_PCT = 10;

    /// @dev KARMA total supply: 1_000_000_000 * 1e18, zero inflation forever
    uint256 internal constant KARMA_TOTAL_SUPPLY = 1_000_000_000 ether;

    /// @dev Allocation percentages
    uint256 internal constant ALLOC_TEAM_PCT = 15;
    uint256 internal constant ALLOC_INVESTOR_PCT = 12;
    uint256 internal constant ALLOC_ECOSYSTEM_PCT = 28;
    uint256 internal constant ALLOC_MINING_PCT = 25;
    uint256 internal constant ALLOC_TGE_PCT = 15;
    uint256 internal constant ALLOC_TREASURY_PCT = 5;

    /// @dev Stake tier minimums
    uint256 internal constant TIER2_MIN = 100_000 ether;
    uint256 internal constant TIER3_MIN = 500_000 ether;
    uint256 internal constant TIER4_MIN = 5_000_000 ether;

    /// @dev Lock durations
    uint256 internal constant TIER2_LOCK = 180 days;
    uint256 internal constant TIER3_LOCK = 365 days;

    /// @dev Duration multipliers (scaled by 1e18)
    uint256 internal constant MULT_BASE = 1e18;
    uint256 internal constant MULT_3M = 15e17; // 1.5x
    uint256 internal constant MULT_12M = 2e18; // 2.0x
    uint256 internal constant DURATION_3M = 90 days;
    uint256 internal constant DURATION_12M = 365 days;

    /// @dev Governance
    uint256 internal constant VOTING_PERIOD = 7 days;
    uint256 internal constant QUORUM_BPS = 5100; // 51% of votes cast must be FOR
    /// @dev Minimum participation: cast votes must be >= this share of totalVotingWeight
    uint256 internal constant QUORUM_PARTICIPATION_BPS = 1000; // 10%

    /// @dev Multisig thresholds
    uint256 internal constant MULTISIG_OWNERS = 7;
    uint256 internal constant MULTISIG_EXEC_THRESHOLD = 5; // >=5/7 for fund ops
    uint256 internal constant MULTISIG_CONTROLLER_THRESHOLD = 7; // 7/7 for controller ops

    /// @dev Automation cadence
    uint256 internal constant WEEKLY_DISTRIBUTION_INTERVAL = 7 days;

    /// @dev Dead address for burns
    address internal constant BURN_ADDRESS = address(0x000000000000000000000000000000000000dEaD);

    /// @dev Arbitration
    uint256 internal constant ARBITRATOR_PANEL_SIZE = 15;

    // ── Cocreation Score v1 ──────────────────────────────────────────────────
    /// @dev Cumulative C_event weight required before ContributionNFT mint
    uint256 internal constant MINT_THRESHOLD_WEIGHT = 200;
    /// @dev R_contrib normalization reference (log1p curve)
    uint256 internal constant COCREATION_C_REF = 5000;
    /// @dev Decay windows
    uint256 internal constant DECAY_HOT_DAYS = 90;
    uint256 internal constant DECAY_WARM_DAYS = 365;
    /// @dev Decay factors in BPS (10000 = 1.0)
    uint256 internal constant DECAY_HOT_BPS = 10_000;
    uint256 internal constant DECAY_WARM_BPS = 5_000;
    uint256 internal constant DECAY_COLD_BPS = 2_000;

    /// @dev Score mix BPS (must sum to 10_000 per role)
    uint256 internal constant BUILDER_SETTLE_MIX_BPS = 2500;
    uint256 internal constant BUILDER_CONTRIB_MIX_BPS = 6000;
    uint256 internal constant BUILDER_STAKE_MIX_BPS = 1500;
    uint256 internal constant EXPERT_SETTLE_MIX_BPS = 2000;
    uint256 internal constant EXPERT_CONTRIB_MIX_BPS = 7000;
    uint256 internal constant EXPERT_STAKE_MIX_BPS = 1000;
}
