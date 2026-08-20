export type TelegramWebAppUser = {
  id?: number;
  username?: string;
  first_name?: string;
};

export type TelegramWebApp = {
  ready: () => void;
  expand: () => void;
  initData?: string;
  initDataUnsafe?: { user?: TelegramWebAppUser };
  themeParams?: Record<string, string>;
  close?: () => void;
};

declare global {
  interface Window {
    Telegram?: { WebApp?: TelegramWebApp };
  }
}

/** Client-side Telegram WebApp detect. Server must still verify initData in Karma main. */
export function getTelegramWebApp(): TelegramWebApp | null {
  if (typeof window === "undefined") return null;
  return window.Telegram?.WebApp ?? null;
}

export function bootstrapTelegramWebApp(): TelegramWebApp | null {
  const wa = getTelegramWebApp();
  if (!wa) return null;
  try {
    wa.ready();
    wa.expand();
  } catch {
    // ignore host quirks
  }
  return wa;
}

export function isMiniAppView(): boolean {
  if (typeof window === "undefined") return false;
  const q = new URLSearchParams(window.location.search);
  return q.get("view") === "miniapp" || Boolean(getTelegramWebApp());
}
