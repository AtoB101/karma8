// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IMultiTierStake {
    enum Tier {
        None,
        Public, // Tier 1
        Developer, // Tier 2
        Verifier, // Tier 3
        Partner // Tier 4
    }

    function stakeOf(address account) external view returns (uint256);
    function tierOf(address account) external view returns (Tier);
    function votingWeight(address account) external view returns (uint256);
    function durationMultiplier(address account) external view returns (uint256);
    function isActiveVerifier(address account) external view returns (bool);
    function slash(address account, uint256 amount, bool permanentBan) external;
    function verifierCount() external view returns (uint256);
    function verifierAt(uint256 index) external view returns (address);
    function totalVotingWeight() external view returns (uint256);
    function feeBpsFor(address account) external view returns (uint256);
}
