// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {FeeBridge} from "../src/integration/FeeBridge.sol";
import {SettlementMirror} from "../src/integration/SettlementMirror.sol";
import {CoreEscrowAdapter} from "../src/integration/CoreEscrowAdapter.sol";
import {Treasury} from "../src/treasury/Treasury.sol";
import {DisputeArbitrator} from "../src/arbitration/DisputeArbitrator.sol";
import {DeveloperRewardPool} from "../src/pools/DeveloperRewardPool.sol";

/// @notice Re-wire / verify karma-economy ↔ karma-core (KarmaBilateral) linkage after deploy.
/// @dev Economy-side calls require the broadcast key to be FeeBridge/Mirror/Escrow governance
///      (usually MultiSig executor) or temporary deployer before handoff.
///
/// Env:
///   FEE_BRIDGE_ADDRESS
///   SETTLEMENT_MIRROR_ADDRESS
///   CORE_ESCROW_ADAPTER_ADDRESS (optional)
///   TREASURY_ADDRESS
///   ARBITRATOR_ADDRESS (optional)
///   DEVELOPER_POOL_ADDRESS (optional)
///   KARMA_CORE_ADDRESS          — KarmaBilateral
///   SET_CORE=true|false         — call FeeBridge.setCore (default true)
///   VERIFY_ONLY=true|false      — skip writes, only print checklist (default false)
contract WireKarmaCore is Script {
    function run() external {
        address feeBridge = vm.envAddress("FEE_BRIDGE_ADDRESS");
        address mirror = vm.envAddress("SETTLEMENT_MIRROR_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address karmaCore = vm.envAddress("KARMA_CORE_ADDRESS");
        address escrow = vm.envOr("CORE_ESCROW_ADAPTER_ADDRESS", address(0));
        address arbitrator = vm.envOr("ARBITRATOR_ADDRESS", address(0));
        address devPool = vm.envOr("DEVELOPER_POOL_ADDRESS", address(0));
        bool verifyOnly = vm.envOr("VERIFY_ONLY", false);
        bool setCore = vm.envOr("SET_CORE", true);

        FeeBridge bridge = FeeBridge(feeBridge);
        SettlementMirror settlementMirror = SettlementMirror(mirror);

        console2.log("FeeBridge", feeBridge);
        console2.log("SettlementMirror", mirror);
        console2.log("Treasury", treasury);
        console2.log("KarmaCore", karmaCore);
        console2.log("bridge.core (before)", bridge.core());
        console2.log("mirror reporter[bridge]", settlementMirror.isReporter(feeBridge));
        console2.log("treasury.enableRevenueMode", Treasury(treasury).enableRevenueMode());

        if (!verifyOnly) {
            vm.startBroadcast();
            if (setCore) {
                bridge.setCore(karmaCore);
                console2.log("FeeBridge.setCore done");
            }
            if (!settlementMirror.isReporter(feeBridge)) {
                settlementMirror.setReporter(feeBridge, true);
                console2.log("SettlementMirror.setReporter(FeeBridge) done");
            }
            if (escrow != address(0) && !settlementMirror.isReporter(escrow)) {
                settlementMirror.setReporter(escrow, true);
                console2.log("SettlementMirror.setReporter(Escrow) done");
            }
            if (escrow != address(0) && arbitrator != address(0)) {
                CoreEscrowAdapter(escrow).setArbitrator(arbitrator);
                DisputeArbitrator(arbitrator).setCoreEscrowAdapter(escrow);
                DisputeArbitrator(arbitrator).setKarmaCore(mirror);
                console2.log("Escrow adapter <-> arbitrator wired");
            }
            if (devPool != address(0)) {
                // Requires treasury caller — skipped unless broadcast identity is treasury.
                try DeveloperRewardPool(devPool).setKarmaCore(mirror) {
                    console2.log("DeveloperRewardPool.setKarmaCore(mirror) done");
                } catch {
                    console2.log("SKIP DeveloperRewardPool.setKarmaCore - call via Treasury");
                }
            }
            try Treasury(treasury).setKarmaCore(karmaCore) {
                console2.log("Treasury.setKarmaCore(bilateral) done");
            } catch {
                console2.log("SKIP Treasury.setKarmaCore - call via MultiSig controller");
            }
            vm.stopBroadcast();
        }

        console2.log("--- Karma Bilateral checklist (run on AtoB101/Karma after patch) ---");
        console2.log("1) git apply integrations/karma-core/patches/0001-add-treasury-feebridge.diff");
        console2.log("2) Bilateral.setTreasury(", treasury, ")");
        console2.log("3) Bilateral.setFeeBridge(", feeBridge, ")");
        console2.log("4) Cold-start: settle with revenueMode=false => fee=0, GMV mirrored");
        console2.log("bridge.core (after)", bridge.core());
        console2.log("DONE");
    }
}
