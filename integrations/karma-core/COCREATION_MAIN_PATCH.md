# Cocreation Score — Karma main follow-ups

Economy-side Cocreation Score v1 is implemented in `AtoB101/karma8`:

- `ContributorRegistry` / `ContributionLedger` / `CocreationScoreView`
- `ContributionNFT` mint gated by ledger (`mint_threshold=200`)
- `DeveloperRewardPool` BUILDER registry gate + `previewEpochShare` / `pendingPoints`
- `SettlementMirror` skips GMV attribution on self-deal (`buyer==seller`)

This document lists **Karma-main / off-chain** work that remains outside karma8.

## 1. Off-chain service (priority)

Add `services/cocreation_score.py` (or equivalent) with:

| API | Action |
|-----|--------|
| `POST /v1/cocreation/register` | bind wallet + roles + tracks → call `ContributorRegistry` |
| `POST /v1/cocreation/events` | submit pending contribution |
| `POST /v1/cocreation/events/{id}/accept` | SCENE_OWNER / multisig → `ContributionLedger.accept` |
| `GET /v1/cocreation/score/{wallet}` | read `CocreationScoreView` |
| `POST /v1/cocreation/nft/mint-request` | `ContributionLedger.mintPending` when threshold met |

## 2. ScoringEngine (optional second stage)

- Extend `PartyType` with BUILDER / EXPERT **or** keep parallel registry (preferred to avoid ABI break)
- After Bilateral settle, push `R_settle` via `CocreationScoreView.setSettleRep`
- Keep SUPPLIER/BUYER settlement reputation separate from cocreation contrib weights

## 3. P8 / high-risk

- `high_risk` TEMPLATE_LIVE must require OWNER_CONFIRM before ledger accept with Q > Accepted
- Economy already enforces: non–SCENE_OWNER accepter cannot accept high-risk Q > 0.70

## Config source

- Spec: `docs/cocreation/COCREATION_SCORE_V1.md`
- Drop-in yaml: `docs/cocreation/cocreation_score.v1.yaml`
