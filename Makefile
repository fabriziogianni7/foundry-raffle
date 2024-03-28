-include .env

ANVIL_PK := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

install:;forge install foundry-rs/forge-std smartcontractkit/chainlink-brownie-contracts Cyfrin/foundry-devops OpenZeppelin/openzeppelin-contracts --no-commit

build:; forge build

run-test:; forge test

test-verbose:; forge test -vvv

coverage:; forge coverage

# test-sepolia:; source .env && forge test --mt testFulfillRandomWords --fork-url $SEPOLIA_RPC -vvv
test-sepolia:; forge test  --fork-url $(SEPOLIA_RPC) -vv

deploy-anvil:
	anvil forge script DeployRaffle --rpc-url $(ANVIL_RPC) --private-key $(ANVIL_PK) --broadcast

buy-ticket-anvil:; forge script BuyTicket --rpc-url $(ANVIL_RPC) --private-key $(ANVIL_PK) --broadcast

deploy-sepolia:
	forge script DeployRaffle --rpc-url $(SEPOLIA_RPC) --private-key $(SEPOLIA_PK) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)