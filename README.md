# Foundry CrossChain NFT

# Preview

A cross-chain nft project.

# Installation

# Use

# Note

This NftPoolLockAndRelease is only service for one user once, because it withdraw token need the pool owner to withdraw, and maybe it need to use `mapping` to record the native token balance and link token balance of every user, and change the withdraw function permissions, may the recorded user to withraw their own tokens.
Then if we modify the withdraw function limits, we need to revise the pay function, it only pay by users' balance. What's more, we need a function to deposit some tokens to the pool.

    1. withdraw & withdrawToken
    2. payLink & payNative
    3. deposit
    4. mapping(address => uint256);

## Next to do:

1. fork-test may need to continue. Maybe it can deploy all in the one setUp. Through the select fork to divide the chain. then try to test the message passing.
2. may need a interactions script to test in real chain.

## Now the test coverage:

```json
╭-------------------------------------------+------------------+------------------+----------------+----------------╮
| File                                      | % Lines          | % Statements     | % Branches     | % Funcs        |
+===================================================================================================================+
| script/HelperConfig.s.sol                 | 80.00% (16/20)   | 100.00% (20/20)  | 100.00% (6/6)  | 20.00% (1/5)   |
|-------------------------------------------+------------------+------------------+----------------+----------------|
| script/deploy/DeployMNftPool.s.sol        | 100.00% (5/5)    | 100.00% (5/5)    | 100.00% (0/0)  | 100.00% (1/1)  |
|-------------------------------------------+------------------+------------------+----------------+----------------|
| script/deploy/DeployMoodNft.s.sol         | 100.00% (9/9)    | 100.00% (11/11)  | 100.00% (0/0)  | 100.00% (2/2)  |
|-------------------------------------------+------------------+------------------+----------------+----------------|
| script/deploy/DeployWMoodNft.s.sol        | 100.00% (11/11)  | 100.00% (13/13)  | 100.00% (0/0)  | 100.00% (2/2)  |
|-------------------------------------------+------------------+------------------+----------------+----------------|
| script/deploy/DeployWrappedMNftPool.s.sol | 100.00% (5/5)    | 100.00% (5/5)    | 100.00% (0/0)  | 100.00% (1/1)  |
|-------------------------------------------+------------------+------------------+----------------+----------------|
| src/MNftPoolLockAndRelease.sol            | 94.29% (66/70)   | 91.18% (62/68)   | 53.85% (7/13)  | 93.75% (15/16) |
|-------------------------------------------+------------------+------------------+----------------+----------------|
| src/MoodNft.sol                           | 86.67% (26/30)   | 86.96% (20/23)   | 100.00% (5/5)  | 87.50% (7/8)   |
|-------------------------------------------+------------------+------------------+----------------+----------------|
| src/WMNftPoolMintAndBurn.sol              | 92.45% (49/53)   | 93.48% (43/46)   | 83.33% (5/6)   | 93.33% (14/15) |
|-------------------------------------------+------------------+------------------+----------------+----------------|
| src/WMoodNft.sol                          | 100.00% (8/8)    | 100.00% (6/6)    | 100.00% (0/0)  | 100.00% (2/2)  |
|-------------------------------------------+------------------+------------------+----------------+----------------|
| Total                                     | 92.42% (195/211) | 93.91% (185/197) | 76.67% (23/30) | 86.54% (45/52) |
╰-------------------------------------------+------------------+------------------+----------------+----------------╯
```
