-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil zktest deployMood

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install foundry-rs/forge-std@v1.9.4 --no-commit && forge install openzeppelin/openzeppelin-contracts@v5.1.0 --no-commit && forge install smartcontractkit/chainlink-local@v0.2.3 --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(ETH_SEPOLIA_RPC_URL)  --wallet $(myaccount) --broadcast 
# --private-key $(DEFAULT_ANVIL_KEY)
# --verify --etherscan-api-key $(ETHERSCAN_API_KEY)  -vvvv
endif 
ifeq ($(findstring --network arbsepolia,$(ARGS)),--network arbsepolia)
	NETWORK_ARGS := --rpc-url $(ARB_SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

mintMoodNft:
	@forge script script/interactions/Interactions.s.sol:MintMoodNft ${NETWORK_ARGS}

deployMood:
	@forge script script/deploy/DeployMoodNft.s.sol:DeployMoodNft $(NETWORK_ARGS)
deployWMood:
	@forge script script/deploy/DeployWMoodNft.s.sol:DeployWMoodNft $(NETWORK_ARGS)

deploymnftpool:
	@forge script script/deploy/DeployMNftPool.s.sol:DeployMNftPool $(NETWORK_ARGS)
deploywmnftpool:
	@forge script script/deploy/DeployWrappedMoodNftPool.s.sol:DeployWrappedMoodNftPool $(NETWORK_ARGS)


cast:
	@cast send 

flipMoodOnAnvil:
	@cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 "flipMood(uint256)" 0 --private-key ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --rpc-url http://localhost:8545

mintMoodOnAnvil:
	@cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 "mintNft()" --private-key ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --rpc-url http://localhost:8545