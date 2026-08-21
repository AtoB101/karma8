import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

/**
 * MiniApp embed:
 * - Parent: Telegram / main MiniApp origin (MINIAPP_ORIGIN) — required in production
 * - Child: economy host (KARMA8_ECONOMY_HOST)
 */
function parseOrigins(raw: string | undefined, mode: string): string[] {
  if (!raw) {
    if (mode === "production") {
      throw new Error(
        "MINIAPP_ORIGIN is required for production builds (comma-separated parent origins). Example: https://web.telegram.org,https://your-main-miniapp.example"
      );
    }
    return [
      "http://localhost:5173",
      "http://127.0.0.1:5173",
      "https://web.telegram.org",
      "https://webk.telegram.org",
      "https://webz.telegram.org",
    ];
  }
  return raw
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");
  const rootEnv = loadEnv(mode, `${process.cwd()}/..`, "");
  const origins = parseOrigins(env.MINIAPP_ORIGIN || rootEnv.MINIAPP_ORIGIN, mode);
  const frameAncestors = ["'self'", ...origins].join(" ");

  const headers: Record<string, string> = {
    "Content-Security-Policy": [
      `frame-ancestors ${frameAncestors}`,
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' https://telegram.org",
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
      "font-src 'self' https://fonts.gstatic.com data:",
      "img-src 'self' data: blob: https:",
      "connect-src 'self' https: http://127.0.0.1:* http://localhost:* ws: wss:",
      "object-src 'none'",
      "base-uri 'self'",
    ].join("; "),
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "strict-origin-when-cross-origin",
  };

  return {
    plugins: [react()],
    server: {
      port: 5173,
      host: true,
      headers,
      cors: { origin: origins, credentials: false },
    },
    preview: {
      port: 4173,
      host: true,
      headers,
      cors: { origin: origins, credentials: false },
    },
    publicDir: "public",
  };
});
