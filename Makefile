.PHONY: build test fmt demo-anvil demo-deploy readiness

build:
	forge build

test:
	forge test -vv

fmt:
	forge fmt

flywheel:
	forge test --match-contract FlywheelE2E -vv

demo-anvil:
	anvil --chain-id 31337

demo-deploy:
	forge script script/DeployLocalDemo.s.sol:DeployLocalDemo --rpc-url http://127.0.0.1:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

readiness:
	@echo "See docs/COMMERCIAL_READINESS.md"