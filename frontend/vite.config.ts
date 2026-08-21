import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

/**
 * MiniApp embed (清单 D):
 * - Parent: Telegram / main MiniApp origin (MINIAPP_ORIGIN)
 * - Child: this economy host (KARMA8_ECONOMY_HOST)
 * frame-ancestors allows iframe; CORS helps main BFF fetch /economy-surface.json in preview.
 */
function parseOrigins(raw: string | undefined): string[] {
  if (!raw) {
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
  const origins = parseOrigins(env.MINIAPP_ORIGIN || rootEnv.MINIAPP_ORIGIN);
  const frameAncestors = ["'self'", ...origins].join(" ");

  const headers: Record<string, string> = {
    "Content-Security-Policy": `frame-ancestors ${frameAncestors}`,
    // Allow embedding; do not set X-Frame-Options DENY
  };

  return {
    plugins: [react()],
    server: {
      port: 5173,
      host: true,
      headers,
      cors: {
        origin: origins,
        credentials: false,
      },
    },
    preview: {
      port: 4173,
      host: true,
      headers,
      cors: {
        origin: origins,
        credentials: false,
      },
    },
    publicDir: "public",
  };
});
