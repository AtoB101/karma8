// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ITreasuryFeeSink} from "./ITreasuryFeeSink.sol";
import {SettlementMirror} from "./SettlementMirror.sol";
import {IKarmaCoreView} from "../interfaces/IKarmaCoreView.sol";
import {IMultiTierStake} from "../interfaces/IMultiTierStake.sol";
import {KarmaEconomyConstants} from "../libraries/KarmaEconomyConstants.sol";

/// @title FeeBridge
/// @notice The only write path from karma-core world into karma-economy:
///         pull/receive USDC fee → Treasury.notifyFee + record bill/GMV mirror.
/// @dev karma-core should approve + call `collectAndRecord` (or transfer + `collectFromBalance`).
contract FeeBridge is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdc;
    ITreasuryFeeSink public treasury;
    SettlementMirror public mirror;
    IMultiTierStake public stake;
    address public core; // authorized karma-core reporter
    address public governance;

    event CoreUpdated(address indexed core);
    event TreasuryUpdated(address indexed treasury);
    event GovernanceUpdated(address indexed governance);
    event StakeUpdated(address indexed stake);
    event FeeCollected(bytes32 indexed orderId, address indexed developer, uint256 amountUsdc, uint256 feeUsdc);

    error Unauthorized();
    error RevenueOff();
    error FeeMismatch();

    modifier onlyCore() {
        if (msg.sender != core) revert Unauthorized();
        _;
    }

    modifier onlyGovernance() {
        if (msg.sender != governance) revert Unauthorized();
        _;
    }

    constructor(address usdc_, address treasury_, address mirror_, address stake_, address governance_) {
        require(
            usdc_ != address(0) && treasury_ != address(0) && mirror_ != address(0) && governance_ != address(0), "zero"
        );
        usdc = IERC20(usdc_);
        treasury = ITreasuryFeeSink(treasury_);
        mirror = SettlementMirror(mirror_);
        stake = IMultiTierStake(stake_);
        governance = governance_;
    }

    function setCore(address core_) external onlyGovernance {
        core = core_;
        emit CoreUpdated(core_);
    }

    function setTreasury(address treasury_) external onlyGovernance {
        require(treasury_ != address(0), "zero");
        treasury = ITreasuryFeeSink(treasury_);
        emit TreasuryUpdated(treasury_);
    }

    function setGovernance(address governance_) external onlyGovernance {
        require(governance_ != address(0), "zero");
        governance = governance_;
        emit GovernanceUpdated(governance_);
    }

    function setStake(address stake_) external onlyGovernance {
        stake = IMultiTierStake(stake_);
        emit StakeUpdated(stake_);
    }

    /// @notice Quote fee for a developer using stake tier discounts when revenue mode is on.
    /// @dev Source of truth is Treasury.enableRevenueMode. If stake.revenueMode is desynced/off,
    ///      fall back to base FEE_BPS (do not silently quote 0 for everyone).
    function quoteFeeBps(address developer) public view returns (uint256) {
        if (!treasury.enableRevenueMode()) return 0;
        if (address(stake) != address(0)) {
            try stake.revenueMode() returns (bool stakeOn) {
                if (stakeOn) {
                    try stake.feeBpsFor(developer) returns (uint256 bps) {
                        return bps;
                    } catch {}
                }
            } catch {}
        }
        return KarmaEconomyConstants.FEE_BPS;
    }

    function quoteFee(address developer, uint256 amountUsdc) public view returns (uint256) {
        uint256 bps = quoteFeeBps(developer);
        return (amountUsdc * bps) / KarmaEconomyConstants.BPS_DENOMINATOR;
    }

    /// @notice karma-core settlement hook: pull fee from core escrow wallet and forward to Treasury.
    /// @dev `feeUsdc` MUST equal `quoteFee(developer, amountUsdc)` (0 when revenue off).
    function collectAndRecord(
        bytes32 orderId,
        address buyer,
        address seller,
        address developer,
        uint256 amountUsdc,
        uint256 feeUsdc
    ) external onlyCore nonReentrant {
        uint256 expected = quoteFee(developer, amountUsdc);
        if (feeUsdc != expected) revert FeeMismatch();

        if (feeUsdc > 0) {
            if (!treasury.enableRevenueMode()) revert RevenueOff();
            usdc.safeTransferFrom(msg.sender, address(this), feeUsdc);
            usdc.forceApprove(address(treasury), feeUsdc);
            treasury.notifyFee(feeUsdc);
        }

        mirror.recordBill(
            IKarmaCoreView.BillSnapshot({
                orderId: orderId,
                buyer: buyer,
                seller: seller,
                developer: developer,
                amountUsdc: amountUsdc,
                feeUsdc: feeUsdc,
                settledAt: uint64(block.timestamp),
                disputed: false,
                frozen: false
            })
        );

        emit FeeCollected(orderId, developer, amountUsdc, feeUsdc);
    }
}
