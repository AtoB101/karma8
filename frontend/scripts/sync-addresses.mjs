#!/usr/bin/env node
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";

const network = process.argv[2] || "local";
const src = resolve(process.cwd(), `../deployments/${network}.json`);
const dest = resolve(process.cwd(), ".env.local");

if (!existsSync(src)) {
  console.error(`Missing deployments/${network}.json — run make demo-deploy or fill deployments/${network}.json`);
  process.exit(1);
}

const j = JSON.parse(readFileSync(src, "utf8"));
const bilateral = j.karmaBilateral ?? j.referenceCore ?? j.karmaCore ?? "";
const env = `VITE_CHAIN_ID=${j.chainId ?? ""}
VITE_RPC_URL=${j.rpcUrl ?? ""}
VITE_TREASURY=${j.treasury ?? ""}
VITE_STAKE=${j.stake ?? ""}
VITE_GOVERNOR=${j.governor ?? ""}
VITE_STAKER_POOL=${j.stakerPool ?? ""}
VITE_DEVELOPER_POOL=${j.developerPool ?? ""}
VITE_CONTRIBUTION_NFT=${j.contributionNft ?? ""}
VITE_KARMA=${j.karma ?? ""}
VITE_FEE_BRIDGE=${j.feeBridge ?? ""}
VITE_SETTLEMENT_MIRROR=${j.settlementMirror ?? ""}
VITE_CONTRIBUTOR_REGISTRY=${j.contributorRegistry ?? ""}
VITE_CONTRIBUTION_LEDGER=${j.contributionLedger ?? ""}
VITE_COCREATION_SCORE=${j.cocreationScoreView ?? ""}
VITE_USDC=${j.usdc ?? ""}
VITE_KARMA_BILATERAL=${bilateral}
VITE_ECONOMY_HOST=${j.economyHost ?? process.env.KARMA8_ECONOMY_HOST ?? ""}
`;
writeFileSync(dest, env);
console.log(`Wrote frontend/.env.local from deployments/${network}.json`);
