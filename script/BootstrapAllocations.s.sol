// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {KarmaVesting} from "../src/token/KarmaVesting.sol";
import {KarmaEconomyConstants} from "../src/libraries/KarmaEconomyConstants.sol";

/// @notice Create category grants according to tokenomics percentages.
/// @dev Requires the broadcaster to hold the full KARMA allocation intended for vesting.
contract BootstrapAllocations is Script {
    function run() external {
        address karma = vm.envAddress("KARMA_ADDRESS");
        address vestingAddr = vm.envAddress("VESTING_ADDRESS");
        address team = vm.envAddress("ALLOC_TEAM");
        address investor = vm.envAddress("ALLOC_INVESTOR");
        address ecosystem = vm.envAddress("ALLOC_ECOSYSTEM");
        address mining = vm.envAddress("ALLOC_MINING");
        address tge = vm.envAddress("ALLOC_TGE");
        address treasuryReserve = vm.envAddress("ALLOC_TREASURY_RESERVE");
        uint64 start = uint64(vm.envOr("VESTING_START", block.timestamp));

        KarmaVesting vesting = KarmaVesting(vestingAddr);
        uint256 total = KarmaEconomyConstants.KARMA_TOTAL_SUPPLY;

        uint256 teamAmt = (total * KarmaEconomyConstants.ALLOC_TEAM_PCT) / 100;
        uint256 investorAmt = (total * KarmaEconomyConstants.ALLOC_INVESTOR_PCT) / 100;
        uint256 ecoAmt = (total * KarmaEconomyConstants.ALLOC_ECOSYSTEM_PCT) / 100;
        uint256 miningAmt = (total * KarmaEconomyConstants.ALLOC_MINING_PCT) / 100;
        uint256 tgeAmt = (total * KarmaEconomyConstants.ALLOC_TGE_PCT) / 100;
        uint256 reserveAmt = (total * KarmaEconomyConstants.ALLOC_TREASURY_PCT) / 100;

        vm.startBroadcast();
        IERC20(karma).transfer(vestingAddr, teamAmt + investorAmt + ecoAmt + miningAmt + tgeAmt + reserveAmt);

        uint256 idTeam = vesting.createGrant(KarmaVesting.Category.Team, team, teamAmt, start);
        uint256 idInv = vesting.createGrant(KarmaVesting.Category.Investor, investor, investorAmt, start);
        uint256 idEco = vesting.createGrant(KarmaVesting.Category.Ecosystem, ecosystem, ecoAmt, start);
        uint256 idMine = vesting.createGrant(KarmaVesting.Category.Mining, mining, miningAmt, start);
        uint256 idTge = vesting.createGrant(KarmaVesting.Category.Tge, tge, tgeAmt, start);
        uint256 idRes = vesting.createGrant(KarmaVesting.Category.TreasuryReserve, treasuryReserve, reserveAmt, start);

        console2.log("team grant", idTeam, teamAmt);
        console2.log("investor grant", idInv, investorAmt);
        console2.log("ecosystem grant", idEco, ecoAmt);
        console2.log("mining grant", idMine, miningAmt);
        console2.log("tge grant", idTge, tgeAmt);
        console2.log("reserve grant", idRes, reserveAmt);
        vm.stopBroadcast();
    }
}
