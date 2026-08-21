# Deployments

## Files

| File | Purpose |
|------|---------|
| `addresses.schema.json` | Schema for network address JSON (清单 A) |
| `sepolia.example.json` | Copy → `sepolia.json` and fill after deploy |
| `local.json` | Written by `make demo-deploy` |
| `economy-surface.example.json` | Shape for main `GET /v1/economy/surface` |

## After deploy

```bash
# Fill deployments/sepolia.json (or copy from broadcast logs)
cp deployments/sepolia.example.json deployments/sepolia.json
# edit addresses...

# Root .env — copy keys from JSON (TREASURY_ADDRESS=..., KARMA_BILATERAL=...)
# Frontend
cd frontend && npm run sync-addresses -- sepolia

# ABI for main BFF
make export-abis

# Wiring check
export $(grep -v '^#' .env | xargs)
bash integrations/telegram-miniapp/verify_wiring.sh
```

Cold start: `enableRevenueMode=false` → on-chain fee quote 0; Mirror still records GMV via `collectAndRecord`.
