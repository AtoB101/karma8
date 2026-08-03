// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IKarmaCoreView} from "../interfaces/IKarmaCoreView.sol";

contract MockKarmaCore is IKarmaCoreView {
    mapping(bytes32 => BillSnapshot) internal _bills;
    mapping(address => uint256) public developerGmv;
    uint256 public totalGmv;

    function setBill(BillSnapshot calldata bill) external {
        _bills[bill.orderId] = bill;
    }

    function setDeveloperGmv(address developer, uint256 gmv) external {
        developerGmv[developer] = gmv;
    }

    function setTotalGmv(uint256 gmv) external {
        totalGmv = gmv;
    }

    function getBillSnapshot(bytes32 orderId) external view returns (BillSnapshot memory) {
        return _bills[orderId];
    }

    function getDeveloperGmv(address developer, uint64, uint64) external view returns (uint256) {
        return developerGmv[developer];
    }

    function getTotalGmv(uint64, uint64) external view returns (uint256) {
        return totalGmv;
    }

    function isOrderFrozen(bytes32 orderId) external view returns (bool) {
        return _bills[orderId].frozen;
    }
}