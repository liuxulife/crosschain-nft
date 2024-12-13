# Foundry CrossChain NFT

# Preview

A cross-chain nft project.

# Installation

# Use

cast call 0x5fbdb2315678afecb367f032d93f642f64180aa3 "getSadSvgImageUri()" --private-key DEFAULT_ANVIL_KEY

cast call 0x5fbdb2315678afecb367f032d93f642f64180aa3 "name()" --private-key DEFAULT_ANVIL_KEY

cast call 0x5fbdb2315678afecb367f032d93f642f64180aa3 "mintWithSpecificTokenId(address, uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 0--private-key DEFAULT_ANVIL_KEY

0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001057726170706564204d6f6f64204e465400000000000000000000000000000000

cast call 0x5fbdb2315678afecb367f032d93f642f64180aa3 "mintWithSpecificTokenId(address, uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 0 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --rpc-url http://127.0.0.1:8545 -- --broadcast

# Note

This NftPoolLockAndRelease is only service for one user once, because it withdraw token need the pool owner to withdraw, and maybe it need to use `mapping` to record the native token balance and link token balance of every user, and change the withdraw function permissions, may the recorded user to withraw their own tokens.
Then if we modify the withdraw function limits, we need to revise the pay function, it only pay by users' balance. What's more, we need a function to deposit some tokens to the pool.

1. withdraw & withdrawToken
2. payLink & payNative
3. deposit
4. mapping(address => uint256);


0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165