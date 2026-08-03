/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_TREASURY?: string;
  readonly VITE_STAKE?: string;
  readonly VITE_GOVERNOR?: string;
  readonly VITE_STAKER_POOL?: string;
  readonly VITE_CONTRIBUTION_NFT?: string;
  readonly VITE_KARMA?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}