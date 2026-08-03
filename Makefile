.PHONY: build test fmt demo-anvil demo-deploy readiness golive linkage patch-verify security-local

build:
	forge build

test:
	forge test -vv

fmt:
	forge fmt

flywheel:
	forge test --match-contract FlywheelE2E -vv

golive:
	forge test --match-contract CoreLinkage -vv
	forge test --match-contract GoLiveAcceptance -vv
	forge test --match-contract FlywheelE2E -vv
	forge test --match-contract SecurityHardening -vv
	bash integrations/karma-core/verify_patch.sh

linkage:
	forge test --match-contract CoreLinkage -vv
	bash integrations/karma-core/verify_patch.sh

demo-anvil:
	anvil --chain-id 31337

demo-deploy:
	forge script script/DeployLocalDemo.s.sol:DeployLocalDemo --rpc-url http://127.0.0.1:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

readiness:
	@echo "See docs/GO_LIVE_95.md && docs/COMMERCIAL_READINESS.md"

patch-verify:
	bash integrations/karma-core/verify_patch.sh

security-local:
	forge test --match-contract SecurityHardening -vv
