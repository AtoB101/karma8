// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IContributorRegistry
interface IContributorRegistry {
    enum Role {
        BUILDER,
        EXPERT,
        SCENE_OWNER,
        VERIFIER
    }

    enum Status {
        None,
        Active,
        Suspended
    }

    function isActive(address wallet) external view returns (bool);
    function hasRole(address wallet, Role role) external view returns (bool);
    function statusOf(address wallet) external view returns (Status);
    function tracksOf(address wallet) external view returns (bytes32[] memory);
}
