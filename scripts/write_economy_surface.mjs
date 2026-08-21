#!/usr/bin/env node
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";

const network = process.argv[2] || "local";
const root = resolve(process.cwd());
const src = resolve(root, `deployments/${network}.json`);
const scenariosPath = resolve(root, "deployments/scenarios.json");
const dest = resolve(root, "frontend/public/economy-surface.json");

if (!existsSync(src)) {
  console.error(`Missing ${src}`);
  process.exit(1);
}

const j = JSON.parse(readFileSync(src, "utf8"));
const scenarios = existsSync(scenariosPath)
  ? JSON.parse(readFileSync(scenariosPath, "utf8"))
  : null;

const host = j.economyHost || process.env.KARMA8_ECONOMY_HOST || "http://127.0.0.1:5173";
const surface = {
  chainId: j.chainId ?? 31337,
  rpcUrl: j.rpcUrl ?? "http://127.0.0.1:8545",
  enableRevenueMode: j.enableRevenueMode ?? false,
  feeBpsColdStart: 0,
  feeBpsConstant: j.feeBps ?? 20,
  splitRatios: [40, 30, 20, 10],
  gmvWeightBps: 7000,
  nftWeightBps: 3000,
  mintThresholdWeight: 200,
  contracts: {
    treasury: j.treasury,
    feeBridge: j.feeBridge,
    settlementMirror: j.settlementMirror,
    stake: j.stake,
    governor: j.governor,
    developerPool: j.developerPool,
    stakerPool: j.stakerPool,
    contributionNft: j.contributionNft,
    contributorRegistry: j.contributorRegistry,
    contributionLedger: j.contributionLedger,
    cocreationScoreView: j.cocreationScoreView,
    karmaToken: j.karma,
    usdc: j.usdc,
    karmaBilateral: j.karmaBilateral ?? j.referenceCore,
  },
  embed: {
    economyHost: host,
    miniappUrl: `${host}/?view=miniapp`,
    tabs: ["status", "wallet", "rewards", "contrib"],
    includesVerificationEngine: false,
  },
  scenarios: scenarios
    ? {
        builder: scenarios.builder,
        buyer: scenarios.buyer,
        seller: scenarios.seller,
        builderLifetimeGmv: scenarios.builderLifetimeGmv,
        selfDealDidNotCreditGmv: scenarios.selfDealDidNotCreditGmv,
        orderNormal: scenarios.orderNormal,
        orderSelfDeal: scenarios.orderSelfDeal,
      }
    : null,
  notes: "Main BFF GET /v1/economy/surface may proxy or eth_call these contracts.",
};

mkdirSync(resolve(root, "frontend/public"), { recursive: true });
writeFileSync(dest, JSON.stringify(surface, null, 2) + "\n");
console.log(`Wrote ${dest}`);
