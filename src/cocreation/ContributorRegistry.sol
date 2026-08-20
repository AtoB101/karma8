// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IContributorRegistry} from "../interfaces/IContributorRegistry.sol";

/// @title ContributorRegistry
/// @notice Identity binding for Cocreation Score: wallet + roles + tracks + status.
contract ContributorRegistry is IContributorRegistry {
    address public governance;

    mapping(address => Status) internal _status;
    mapping(address => mapping(Role => bool)) internal _roles;
    mapping(address => bytes32[]) internal _tracks;
    mapping(address => uint64) public registeredAt;

    event GovernanceUpdated(address indexed governance);
    event Registered(address indexed wallet, Role[] roles, bytes32[] tracks);
    event RolesUpdated(address indexed wallet, Role[] roles);
    event TracksUpdated(address indexed wallet, bytes32[] tracks);
    event StatusUpdated(address indexed wallet, Status status);

    error Unauthorized();
    error BadInput();
    error NotRegistered();

    modifier onlyGovernance() {
        if (msg.sender != governance) revert Unauthorized();
        _;
    }

    constructor(address governance_) {
        require(governance_ != address(0), "zero");
        governance = governance_;
    }

    function setGovernance(address g) external onlyGovernance {
        require(g != address(0), "zero");
        governance = g;
        emit GovernanceUpdated(g);
    }

    /// @notice Self-register with roles/tracks (governance can also register others).
    function register(Role[] calldata roles, bytes32[] calldata tracks) external {
        _register(msg.sender, roles, tracks);
    }

    function registerFor(address wallet, Role[] calldata roles, bytes32[] calldata tracks) external onlyGovernance {
        _register(wallet, roles, tracks);
    }

    function setRoles(address wallet, Role[] calldata roles) external onlyGovernance {
        if (_status[wallet] == Status.None) revert NotRegistered();
        _clearRoles(wallet);
        _setRoles(wallet, roles);
        emit RolesUpdated(wallet, roles);
    }

    function setTracks(address wallet, bytes32[] calldata tracks) external {
        if (msg.sender != wallet && msg.sender != governance) revert Unauthorized();
        if (_status[wallet] == Status.None) revert NotRegistered();
        delete _tracks[wallet];
        for (uint256 i = 0; i < tracks.length; i++) {
            _tracks[wallet].push(tracks[i]);
        }
        emit TracksUpdated(wallet, tracks);
    }

    function setStatus(address wallet, Status status_) external onlyGovernance {
        if (_status[wallet] == Status.None) revert NotRegistered();
        if (status_ == Status.None) revert BadInput();
        _status[wallet] = status_;
        emit StatusUpdated(wallet, status_);
    }

    function isActive(address wallet) public view returns (bool) {
        return _status[wallet] == Status.Active;
    }

    function hasRole(address wallet, Role role) public view returns (bool) {
        return _roles[wallet][role];
    }

    function statusOf(address wallet) external view returns (Status) {
        return _status[wallet];
    }

    function tracksOf(address wallet) external view returns (bytes32[] memory) {
        return _tracks[wallet];
    }

    function _register(address wallet, Role[] calldata roles, bytes32[] calldata tracks) internal {
        if (wallet == address(0) || roles.length == 0) revert BadInput();
        if (_status[wallet] == Status.None) {
            registeredAt[wallet] = uint64(block.timestamp);
            _status[wallet] = Status.Active;
        }
        _clearRoles(wallet);
        _setRoles(wallet, roles);
        delete _tracks[wallet];
        for (uint256 i = 0; i < tracks.length; i++) {
            _tracks[wallet].push(tracks[i]);
        }
        emit Registered(wallet, roles, tracks);
    }

    function _setRoles(address wallet, Role[] calldata roles) internal {
        for (uint256 i = 0; i < roles.length; i++) {
            _roles[wallet][roles[i]] = true;
        }
    }

    function _clearRoles(address wallet) internal {
        _roles[wallet][Role.BUILDER] = false;
        _roles[wallet][Role.EXPERT] = false;
        _roles[wallet][Role.SCENE_OWNER] = false;
        _roles[wallet][Role.VERIFIER] = false;
    }
}
