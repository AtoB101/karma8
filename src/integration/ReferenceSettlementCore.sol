// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {FeeBridge} from "./FeeBridge.sol";

/// @title ReferenceSettlementCore
/// @notice Local/reference stand-in for karma-core settle path used in economy E2E demos.
/// @dev Production should use AtoB101/Karma KarmaBilateral + the published treasury patch.
contract ReferenceSettlementCore is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Order {
        address buyer;
        address seller;
        address developer;
        uint256 amountUsdc;
        bool open;
        bool frozen;
    }

    IERC20 public immutable usdc;
    FeeBridge public feeBridge;
    address public admin;

    mapping(bytes32 => Order) public orders;
    mapping(bytes32 => uint256) public escrowOf;

    event OrderOpened(bytes32 indexed orderId, address buyer, address seller, uint256 amount);
    event OrderSettled(bytes32 indexed orderId, uint256 feeUsdc);
    event OrderRefunded(bytes32 indexed orderId);
    event OrderFrozen(bytes32 indexed orderId, bool frozen);

    error Unauthorized();
    error BadState();

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    constructor(address usdc_, address feeBridge_, address admin_) {
        require(usdc_ != address(0) && feeBridge_ != address(0) && admin_ != address(0), "zero");
        usdc = IERC20(usdc_);
        feeBridge = FeeBridge(feeBridge_);
        admin = admin_;
    }

    function setFeeBridge(address b) external onlyAdmin {
        feeBridge = FeeBridge(b);
    }

    function openOrder(bytes32 orderId, address seller, address developer, uint256 amountUsdc) external nonReentrant {
        require(orderId != bytes32(0) && amountUsdc > 0 && seller != address(0), "bad");
        require(!orders[orderId].open && escrowOf[orderId] == 0, "exists");
        usdc.safeTransferFrom(msg.sender, address(this), amountUsdc);
        orders[orderId] = Order({
            buyer: msg.sender, seller: seller, developer: developer, amountUsdc: amountUsdc, open: true, frozen: false
        });
        escrowOf[orderId] = amountUsdc;
        emit OrderOpened(orderId, msg.sender, seller, amountUsdc);
    }

    function settle(bytes32 orderId) external nonReentrant {
        Order storage o = orders[orderId];
        if (!o.open || o.frozen) revert BadState();
        require(msg.sender == o.buyer || msg.sender == o.seller || msg.sender == admin, "auth");

        uint256 amount = o.amountUsdc;
        uint256 fee = feeBridge.quoteFee(o.developer, amount);
        require(fee <= amount, "fee");

        o.open = false;
        escrowOf[orderId] = 0;

        if (fee > 0) {
            usdc.forceApprove(address(feeBridge), fee);
            feeBridge.collectAndRecord(orderId, o.buyer, o.seller, o.developer, amount, fee);
        } else {
            // Still record GMV with zero fee (cold-start / free mode)
            feeBridge.collectAndRecord(orderId, o.buyer, o.seller, o.developer, amount, 0);
        }

        uint256 payout = amount - fee;
        if (payout > 0) usdc.safeTransfer(o.seller, payout);
        emit OrderSettled(orderId, fee);
    }

    /// @notice Escrow controls used by economy CoreEscrowAdapter / ops.
    function freezeOrder(bytes32 orderId) external onlyAdmin {
        orders[orderId].frozen = true;
        emit OrderFrozen(orderId, true);
    }

    function releaseToSeller(bytes32 orderId) external onlyAdmin nonReentrant {
        Order storage o = orders[orderId];
        if (!o.open) revert BadState();
        o.open = false;
        o.frozen = false;
        uint256 amount = escrowOf[orderId];
        escrowOf[orderId] = 0;
        usdc.safeTransfer(o.seller, amount);
        emit OrderSettled(orderId, 0);
    }

    function refundToBuyer(bytes32 orderId) external onlyAdmin nonReentrant {
        Order storage o = orders[orderId];
        if (!o.open) revert BadState();
        o.open = false;
        o.frozen = false;
        uint256 amount = escrowOf[orderId];
        escrowOf[orderId] = 0;
        usdc.safeTransfer(o.buyer, amount);
        emit OrderRefunded(orderId);
    }
}
