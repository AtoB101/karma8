# Security Audit — karma8 / karma-economy

| Field | Value |
|-------|--------|
| Date | 2026-08-21 |
| Scope | `src/**`, `script/Deploy*.s.sol`, `frontend/`, Telegram MiniApp surface |
| Method | Manual code review + existing Foundry suite + new regression tests |
| Branch (fixes) | `cursor/security-hardening-e9e8` |
| Baseline tests | 50/50 pass after remediations |

---

## Executive summary

Audit found **5 Critical** and **several High** issues in governance, FeeBridge/Mirror trust model, and deploy wiring. **Critical on-chain remediations have been applied** in this branch with regression coverage in `test/SecurityAuditRegression.t.sol`.

| Severity | Found | Fixed this pass | Remaining / ops |
|----------|-------|-----------------|-----------------|
| Critical | 5 | 5 | Monitor main-repo Bilateral honesty |
| High | 7 | 3 (DeployEconomy arbitrator, vesting hold, CustomCall bans) | Registry open roles, pool admin brick, escrow try/catch, wash trading |
| Medium | 10 | 0 | Tracked below |
| Low / Info | 10+ | 0 | Tracked below |
| Frontend | 1 High (prod CSP) | Doc only | Ops must set headers |

**Go-live posture:** Cold-start (`enableRevenueMode=false`) + FeeBridge `onlyCore` + immutable fee/splits remain sound. Do **not** enable revenue or hand `CustomCall`/multisig to weak keys until remaining High items are accepted or fixed.

---

## Critical findings (remediated)

### C1 — SettlementMirror GMV replay (fixed)
- **Before:** Same `orderId` could be re-recorded; GMV accumulated again.
- **After:** `require(_bills[orderId].orderId == 0)` — idempotent insert.
- **Test:** `test_MirrorRejectsOrderIdReplayGmvInflation`

### C2 — FeeBridge trusted `feeUsdc` (fixed)
- **Before:** `feeUsdc=0` skipped treasury while still writing GMV under revenue-on.
- **After:** `require(feeUsdc == quoteFee(...))` → `FeeMismatch`.
- **Also:** `quoteFeeBps` uses Treasury as source of truth; if stake `revenueMode` desynced off, fall back to base `FEE_BPS` (not silent 0 for all).
- **Test:** `test_FeeBridgeRejectsUnderquotedFeeWhenRevenueOn`

### C3 — Multisig `rotateOwner` via Standard 5/7 (fixed)
- **Before:** Submitter chose `OpKind.Standard` for self-call → 5/7 owner rotation.
- **After:** Any `to == address(this)` requires 7/7 controller threshold.
- **Test:** `test_MultiSigStandardCannotRotateOwner`

### C4 — Governor quorum = % of cast votes only (fixed)
- **Before:** One tiny staker could propose+vote FOR alone and execute.
- **After:** Cast votes must be ≥ **10%** of `totalVotingWeight` **and** ≥ 51% FOR among cast.
- **Test:** `test_GovernorRequiresParticipationQuorum`

### C5 — `CustomCall` privilege escalation (mitigated)
- **Before:** Ban list only mentioned non-existent fee setters.
- **After:** Also bans `setGovernance` / `setCore` / `setReporter` / `setEnableRevenueMode` / `setRevenueMode` / `slash` / `setTreasury`.
- **Test:** `test_GovernorRejectsDangerousCustomCallSelectors`
- **Residual:** Prefer deny-by-default allowlist long-term; guardian cancel remains.

---

## High (partially fixed / open)

| ID | Issue | Status |
|----|-------|--------|
| H1 | `DeployEconomy` never set `verifierPool.setArbitrator` before `onlyTreasury` handoff | **Fixed** in `DeployEconomy.s.sol` |
| H2 | Investor `markInvestorStakeHold` without stake | **Fixed** — mark + claim require `stakeOf > 0` |
| H3 | `ContributorRegistry.register` self-assigns BUILDER/VERIFIER | **Fixed** — self-register cannot take BUILDER/SCENE_OWNER/VERIFIER |
| H4 | Pool admin bricked after `setTreasury(Treasury)` | **Open** — rotate via redeploy/multisig ops runbook |
| H5 | `CoreEscrowAdapter` swallows freeze/release failures | **Fixed** — fail-hard; requires `coreTarget` |
| H6 | FeeBridge/`onlyCore` trusts Bilateral for all bill fields | **Accepted trust** if core is audited Karma Bilateral; keep `setCore` behind 7/7 |
| H7 | Two-EOA wash GMV (`buyer!=seller` both attacker) | **Open** — main Policy / risk; Mirror only blocks exact self-deal |

---

## Medium / Low (open)

| ID | Sev | Issue |
|----|-----|-------|
| M1 | Med | `Treasury.onUsdcReceived` permissionless accounting inflate |
| M2 | Med | Staker rewards not checkpointed on unstake |
| M3 | Med | `notifyReward` with zero voting weight can trap USDC |
| M4 | Med | Partner in verifier list but not `isActiveVerifier` |
| M5 | Med | Dispute RNG (`prevrandao`) / tie→seller |
| M6 | Med | `AutoBuyBurn.executeBuyBurn` permissionless when unpaused |
| M7 | Med | Vesting `createGrant` without escrow |
| M8 | Med | FeeBridge leftover USDC / approval surface |
| M9 | Med | `ReferenceSettlementCore` admin powers (demo — do not use in prod) |
| L1 | Low | `Treasury.notifyFee` permissionless dust |
| L2 | Low | `FeeBridge.setCore(0)` disables collection |
| L3 | Low | Ledger reject leaves orphan event id lists |

---

## Already strong controls

- Immutable `FEE_BPS` / splits (constants, no setters; Certora + tests)
- Revenue default OFF; claims gated `RevenueOff`
- Self-deal `buyer==seller` skips developer GMV
- FeeBridge `onlyCore` + Mirror `onlyReporter`
- Soulbound ContributionNFT; KARMA fixed supply
- Buyback paused by default
- Multisig 5/7 vs 7/7 (now correctly enforced for self-calls)
- `SecurityHardening.t.sol` + **new** `SecurityAuditRegression.t.sol`

---

## Frontend / Telegram

| ID | Sev | Issue | Action |
|----|-----|-------|--------|
| F1 | High | Vite CSP/`frame-ancestors` only on dev/preview | **Ops:** set same headers on production CDN |
| F2 | Med | Unsigned `telegram-web-app.js` (no SRI) | Pin/vendor + integrity |
| F3 | Med | No address/chainId guard before writes | Validate `getAddress` + chain match |
| F4 | Low | `initDataUnsafe` display only | Keep; main must HMAC-verify |
| Pass | — | No XSS sinks; claim ABI not privileged; no secrets in repo | — |

Trust boundary (intentional): Verification / SIWE / initData / Bot webhook stay on **Karma main**. karma8 MiniApp must not gate value on client TG id.

---

## Main-repo (Karma) alignment notes

1. Bilateral must call `quoteFee` then `collectAndRecord` with **exact** fee (now enforced).
2. Unique `orderId = bytes32(bindingId)` — replays revert on Mirror.
3. Never point FeeBridge.core at untrusted code; `setCore` is 7/7.
4. Production settle must not use `ReferenceSettlementCore`.

---

## Remediation checklist

- [x] C1–C5 on-chain fixes + regression tests  
- [x] DeployEconomy arbitrator wiring  
- [x] Investor vesting stake checks  
- [ ] H3 Registry role gating (before revenue)  
- [ ] H4 Pool admin via governance  
- [ ] H5 Escrow adapter fail-hard  
- [ ] F1 Production CSP headers  
- [ ] External audit before mainnet revenue ON  

---

## Commands

```bash
forge test --match-contract SecurityAuditRegression -vv
forge test --match-contract SecurityHardening -vv
make golive
```
