export const treasuryAbi = [
  {
    type: "function",
    name: "enableRevenueMode",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "bool" }],
  },
  {
    type: "function",
    name: "feeBps",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "splitRatios",
    stateMutability: "view",
    inputs: [],
    outputs: [
      { type: "uint256" },
      { type: "uint256" },
      { type: "uint256" },
      { type: "uint256" },
    ],
  },
] as const;

export const stakeAbi = [
  {
    type: "function",
    name: "stake",
    stateMutability: "nonpayable",
    inputs: [
      { name: "amount", type: "uint256" },
      { name: "tier", type: "uint8" },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "unstake",
    stateMutability: "nonpayable",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: [],
  },
  {
    type: "function",
    name: "stakeOf",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "tierOf",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "uint8" }],
  },
  {
    type: "function",
    name: "votingWeight",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "feeBpsFor",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "isActiveVerifier",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "bool" }],
  },
  {
    type: "function",
    name: "revenueMode",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "bool" }],
  },
] as const;

export const governorAbi = [
  {
    type: "function",
    name: "proposeEnableRevenue",
    stateMutability: "nonpayable",
    inputs: [
      { name: "enable", type: "bool" },
      { name: "description", type: "string" },
    ],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "vote",
    stateMutability: "nonpayable",
    inputs: [
      { name: "id", type: "uint256" },
      { name: "support", type: "bool" },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "execute",
    stateMutability: "nonpayable",
    inputs: [{ name: "id", type: "uint256" }],
    outputs: [],
  },
  {
    type: "function",
    name: "state",
    stateMutability: "view",
    inputs: [{ name: "id", type: "uint256" }],
    outputs: [
      { name: "active", type: "bool" },
      { name: "succeeded", type: "bool" },
      { name: "executed", type: "bool" },
      { name: "forVotes", type: "uint256" },
      { name: "againstVotes", type: "uint256" },
    ],
  },
] as const;

export const stakerPoolAbi = [
  {
    type: "function",
    name: "earned",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "claim",
    stateMutability: "nonpayable",
    inputs: [],
    outputs: [],
  },
  {
    type: "function",
    name: "revenueMode",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "bool" }],
  },
] as const;

export const developerPoolAbi = [
  {
    type: "function",
    name: "pendingPoints",
    stateMutability: "view",
    inputs: [{ name: "developer", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "claimableOf",
    stateMutability: "view",
    inputs: [{ name: "developer", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "isDeveloper",
    stateMutability: "view",
    inputs: [{ name: "developer", type: "address" }],
    outputs: [{ type: "bool" }],
  },
  {
    type: "function",
    name: "GMV_WEIGHT_BPS",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "NFT_WEIGHT_BPS",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "revenueMode",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "bool" }],
  },
] as const;

export const contributionNftAbi = [
  {
    type: "function",
    name: "totalWeightOf",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "balanceOf",
    stateMutability: "view",
    inputs: [{ name: "owner", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
] as const;

export const contributionLedgerAbi = [
  {
    type: "function",
    name: "pendingMintWeight",
    stateMutability: "view",
    inputs: [{ name: "wallet", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "activeContribution",
    stateMutability: "view",
    inputs: [{ name: "wallet", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "lifetimeAcceptedWeight",
    stateMutability: "view",
    inputs: [{ name: "wallet", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
] as const;

export const contributorRegistryAbi = [
  {
    type: "function",
    name: "isActive",
    stateMutability: "view",
    inputs: [{ name: "wallet", type: "address" }],
    outputs: [{ type: "bool" }],
  },
  {
    type: "function",
    name: "hasRole",
    stateMutability: "view",
    inputs: [
      { name: "wallet", type: "address" },
      { name: "role", type: "uint8" },
    ],
    outputs: [{ type: "bool" }],
  },
] as const;

export const cocreationScoreAbi = [
  {
    type: "function",
    name: "scoreBuilder",
    stateMutability: "view",
    inputs: [{ name: "wallet", type: "address" }],
    outputs: [
      { name: "score", type: "uint256" },
      { name: "rS", type: "uint256" },
      { name: "rC", type: "uint256" },
      { name: "rK", type: "uint256" },
    ],
  },
  {
    type: "function",
    name: "scoreExpert",
    stateMutability: "view",
    inputs: [{ name: "wallet", type: "address" }],
    outputs: [
      { name: "score", type: "uint256" },
      { name: "rS", type: "uint256" },
      { name: "rC", type: "uint256" },
      { name: "rK", type: "uint256" },
    ],
  },
] as const;

export const feeBridgeAbi = [
  {
    type: "function",
    name: "core",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "address" }],
  },
  {
    type: "function",
    name: "quoteFeeBps",
    stateMutability: "view",
    inputs: [{ name: "developer", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "quoteFee",
    stateMutability: "view",
    inputs: [
      { name: "developer", type: "address" },
      { name: "amountUsdc", type: "uint256" },
    ],
    outputs: [{ type: "uint256" }],
  },
] as const;

export const settlementMirrorAbi = [
  {
    type: "function",
    name: "isReporter",
    stateMutability: "view",
    inputs: [{ name: "reporter", type: "address" }],
    outputs: [{ type: "bool" }],
  },
  {
    type: "function",
    name: "getDeveloperGmv",
    stateMutability: "view",
    inputs: [
      { name: "developer", type: "address" },
      { name: "fromTs", type: "uint64" },
      { name: "toTs", type: "uint64" },
    ],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "lifetimeDeveloperGmv",
    stateMutability: "view",
    inputs: [{ name: "developer", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
] as const;

export const TIER = {
  None: 0,
  Public: 1,
  Developer: 2,
  Verifier: 3,
  Partner: 4,
} as const;

export const ROLE = {
  BUILDER: 0,
  EXPERT: 1,
  SCENE_OWNER: 2,
  VERIFIER: 3,
} as const;

export type EconomyAddresses = {
  treasury: `0x${string}`;
  stake: `0x${string}`;
  governor: `0x${string}`;
  stakerPool: `0x${string}`;
  developerPool: `0x${string}`;
  contributionNft: `0x${string}`;
  karmaToken: `0x${string}`;
  feeBridge: `0x${string}`;
  settlementMirror: `0x${string}`;
  contributorRegistry: `0x${string}`;
  contributionLedger: `0x${string}`;
  cocreationScore: `0x${string}`;
  usdc: `0x${string}`;
  karmaBilateral: `0x${string}`;
};

export const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000" as const;
