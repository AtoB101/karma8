// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {KarmaEconomyConstants} from "../libraries/KarmaEconomyConstants.sol";
import {IAutomationCompatible} from "../interfaces/IAutomationCompatible.sol";
import {IRewardPool} from "../interfaces/IRewardPool.sol";

/// @title Treasury
/// @notice Decentralized treasury receiving USDC fees from karma-core.
/// @dev Split ratios 40/30/20/10 are immutable constants. enableRevenueMode defaults false.
contract Treasury is IAutomationCompatible, ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum SubsidyKind {
        DeveloperDividend,
        StakerDividend,
        NodeReward,
        BuyBurn,
        GovernanceEcoSubsidy
    }

    IERC20 public immutable usdc;
    address public immutable developerPool;
    address public immutable stakerPool;
    address public immutable verifierPool;
    address public immutable buyBurnPool;

    address public controller; // 7/7 multisig
    address public governance;
    address public karmaCore; // only allowed USDC payer identity (informational)

    /// @notice Global revenue switch. Default false — all distribution disabled.
    bool public enableRevenueMode;

    uint256 public lastDistributionAt;
    uint256 public totalReceived;
    uint256 public totalDistributed;
    uint256 public pendingSubsidyBudget;

    event FeeReceived(address indexed from, uint256 amount);
    event Distributed(uint256 total, uint256 developer, uint256 staker, uint256 verifier, uint256 buyburn);
    event RevenueModeUpdated(bool enabled);
    event SubsidyExecuted(SubsidyKind kind, address indexed pool, uint256 amount, bytes32 proposalId);
    event ControllerUpdated(address indexed controller);
    event GovernanceUpdated(address indexed governance);
    event KarmaCoreUpdated(address indexed karmaCore);

    error Unauthorized();
    error RevenueOff();
    error InvalidSubsidy();
    error TooEarly();
    error PrivateTransferForbidden();

    modifier onlyController() {
        if (msg.sender != controller) revert Unauthorized();
        _;
    }

    modifier onlyGovernance() {
        if (msg.sender != governance) revert Unauthorized();
        _;
    }

    constructor(
        address usdc_,
        address controller_,
        address developerPool_,
        address stakerPool_,
        address verifierPool_,
        address buyBurnPool_,
        address karmaCore_
    ) {
        require(
            usdc_ != address(0) && controller_ != address(0) && developerPool_ != address(0)
                && stakerPool_ != address(0) && verifierPool_ != address(0) && buyBurnPool_ != address(0),
            "zero"
        );
        usdc = IERC20(usdc_);
        controller = controller_;
        developerPool = developerPool_;
        stakerPool = stakerPool_;
        verifierPool = verifierPool_;
        buyBurnPool = buyBurnPool_;
        karmaCore = karmaCore_;
        lastDistributionAt = block.timestamp;
        // enableRevenueMode defaults to false
    }

    function setController(address c) external onlyController {
        require(c != address(0), "zero");
        controller = c;
        emit ControllerUpdated(c);
    }

    function setGovernance(address g) external onlyController {
        require(g != address(0), "zero");
        governance = g;
        emit GovernanceUpdated(g);
    }

    function setKarmaCore(address core) external onlyController {
        karmaCore = core;
        emit KarmaCoreUpdated(core);
    }

    /// @notice Enable/disable full economic flywheel. Intended via governance -> controller path.
    function setEnableRevenueMode(bool enabled) external onlyGovernance {
        enableRevenueMode = enabled;
        // Propagate to child pools (best-effort)
        _trySetRevenue(developerPool, enabled);
        _trySetRevenue(stakerPool, enabled);
        _trySetRevenue(verifierPool, enabled);
        _trySetRevenue(buyBurnPool, enabled);
        emit RevenueModeUpdated(enabled);
    }

    /// @notice karma-core (or any fee payer) transfers USDC here after approve, or use transfer+notify.
    function notifyFee(uint256 amount) external nonReentrant {
        require(amount > 0, "amount");
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        totalReceived += amount;
        emit FeeReceived(msg.sender, amount);
    }

    /// @notice Direct receive accounting when USDC already transferred in.
    function onUsdcReceived(uint256 amount) external {
        // Anyone can acknowledge inbound balance growth; accounting only.
        totalReceived += amount;
        emit FeeReceived(msg.sender, amount);
    }

    function checkUpkeep(bytes calldata)
        external
        view
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded = enableRevenueMode
            && block.timestamp >= lastDistributionAt + KarmaEconomyConstants.WEEKLY_DISTRIBUTION_INTERVAL
            && usdc.balanceOf(address(this)) > pendingSubsidyBudget;
        performData = bytes("");
    }

    function performUpkeep(bytes calldata) external nonReentrant {
        if (!enableRevenueMode) revert RevenueOff();
        if (block.timestamp < lastDistributionAt + KarmaEconomyConstants.WEEKLY_DISTRIBUTION_INTERVAL) {
            revert TooEarly();
        }
        _distribute();
    }

    /// @notice Manual distribution trigger (still requires revenue mode).
    function distributeNow() external nonReentrant onlyController {
        if (!enableRevenueMode) revert RevenueOff();
        _distribute();
    }

    /// @notice Governance-approved ecological subsidy — only to known pool sinks, never private EOAs.
    function executeSubsidy(SubsidyKind kind, uint256 amount, bytes32 proposalId)
        external
        nonReentrant
        onlyGovernance
    {
        if (!enableRevenueMode) revert RevenueOff();
        address pool = _poolFor(kind);
        if (pool == address(0)) revert InvalidSubsidy();
        require(amount > 0 && amount <= usdc.balanceOf(address(this)), "amount");

        usdc.forceApprove(pool, amount);
        IRewardPool(pool).notifyReward(amount);
        totalDistributed += amount;
        emit SubsidyExecuted(kind, pool, amount, proposalId);
    }

    /// @dev Explicit hard block: no arbitrary private transfers.
    function transfer(address, uint256) external pure {
        revert PrivateTransferForbidden();
    }

    /// @notice Immutable split getters for integrators / audits.
    function splitRatios() external pure returns (uint256, uint256, uint256, uint256) {
        return (
            KarmaEconomyConstants.DEVELOPER_POOL_PCT,
            KarmaEconomyConstants.STAKER_POOL_PCT,
            KarmaEconomyConstants.VERIFIER_POOL_PCT,
            KarmaEconomyConstants.BUYBURN_POOL_PCT
        );
    }

    function feeBps() external pure returns (uint256) {
        return KarmaEconomyConstants.FEE_BPS;
    }

    function _distribute() internal {
        uint256 bal = usdc.balanceOf(address(this));
        // Keep no reserved subsidy by default; full balance is distributable weekly
        uint256 amount = bal;
        if (amount == 0) {
            lastDistributionAt = block.timestamp;
            return;
        }

        uint256 toDev = (amount * KarmaEconomyConstants.DEVELOPER_POOL_PCT) / 100;
        uint256 toStaker = (amount * KarmaEconomyConstants.STAKER_POOL_PCT) / 100;
        uint256 toVerifier = (amount * KarmaEconomyConstants.VERIFIER_POOL_PCT) / 100;
        uint256 toBuyBurn = amount - toDev - toStaker - toVerifier; // residual = 10%

        _push(developerPool, toDev);
        _push(stakerPool, toStaker);
        _push(verifierPool, toVerifier);
        _push(buyBurnPool, toBuyBurn);

        totalDistributed += amount;
        lastDistributionAt = block.timestamp;
        emit Distributed(amount, toDev, toStaker, toVerifier, toBuyBurn);
    }

    function _push(address pool, uint256 amount) internal {
        if (amount == 0) return;
        usdc.forceApprove(pool, amount);
        IRewardPool(pool).notifyReward(amount);
    }

    function _poolFor(SubsidyKind kind) internal view returns (address) {
        if (kind == SubsidyKind.DeveloperDividend) return developerPool;
        if (kind == SubsidyKind.StakerDividend) return stakerPool;
        if (kind == SubsidyKind.NodeReward) return verifierPool;
        if (kind == SubsidyKind.BuyBurn || kind == SubsidyKind.GovernanceEcoSubsidy) return buyBurnPool;
        return address(0);
    }

    function _trySetRevenue(address pool, bool enabled) internal {
        (bool ok,) = pool.call(abi.encodeWithSignature("setRevenueMode(bool)", enabled));
        ok; // ignore
    }
}