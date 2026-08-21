.PHONY: build test fmt demo-anvil demo-deploy readiness golive linkage cocreation patch-verify cross-repo security-local export-abis verify-wiring tg-demo tg-seed

build:
	forge build

test:
	forge test -vv

fmt:
	forge fmt

export-abis:
	bash scripts/export-abis.sh

verify-wiring:
	bash integrations/telegram-miniapp/verify_wiring.sh

tg-demo:
	bash integrations/telegram-miniapp/run_tg_local_demo.sh

tg-seed:
	forge script script/SeedTelegramScenarios.s.sol:SeedTelegramScenarios --rpc-url http://127.0.0.1:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
	node scripts/write_economy_surface.mjs local
	cd frontend && npm run sync-addresses -- local

flywheel:
	forge test --match-contract FlywheelE2E -vv

golive:
	forge test --match-contract CoreLinkage -vv
	forge test --match-contract CocreationScore -vv
	forge test --match-contract GoLiveAcceptance -vv
	forge test --match-contract FlywheelE2E -vv
	forge test --match-contract SecurityHardening -vv
	bash integrations/karma-core/verify_patch.sh

linkage:
	forge test --match-contract CoreLinkage -vv
	bash integrations/karma-core/verify_patch.sh
	bash integrations/karma-core/run_cross_repo_test.sh

cocreation:
	forge test --match-contract CocreationScore -vv

cross-repo:
	bash integrations/karma-core/run_cross_repo_test.sh

demo-anvil:
	anvil --chain-id 31337

demo-deploy:
	forge script script/DeployLocalDemo.s.sol:DeployLocalDemo --rpc-url http://127.0.0.1:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

readiness:
	@echo "See docs/GO_LIVE_95.md && docs/COMMERCIAL_READINESS.md && docs/cocreation/COCREATION_SCORE_V1.md"

patch-verify:
	bash integrations/karma-core/verify_patch.sh

security-local:
	forge test --match-contract SecurityHardening -vv
