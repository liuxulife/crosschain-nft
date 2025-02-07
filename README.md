# Foundry CrossChain NFT

# Preview

A cross-chain nft project.
本项目旨在实现跨链 NFT（非同质化代币）的转移和管理。通过使用 Solidity 编写智能合约，并利用 Foundry 进行测试和部署，意在实现 NFT 在不同区块链网络之间的无缝转移。

## 核心功能

- **NFT 铸造和转移**：支持 NFT 的铸造、转移和锁定功能。
- **跨链通信**：设计并实现跨链通信机制，确保 NFT 可以在不同区块链网络之间安全转移。

## 核心合约

### MNftPoolLockAndRelease.sol

```javascript
contract MNftPoolLockAndRelease is CCIPReceiver, OwnerIsCreator {
    using SafeERC20 for IERC20;

    // 错误定义
    error MNftPoolLockAndRelease__DestinationChainNotAllowlisted(uint64 destinationChainSelector);
    error MNftPoolLockAndRelease__SourceChainNotAllowed(uint64 sourceChainSelector);
    error MNftPoolLockAndRelease__SenderNotAllowed(address sender);
    error MNftPoolLockAndRelease__InvalidReceiverAddress();
    error MNftPoolLockAndRelease__NotEnoughBalance(uint256 balance, uint256 required);
    error MNftPoolLockAndRelease__NothingToWithdraw();
    error MNftPoolLockAndRelease__FailedToWithdrawEth(address sender, address beneficiary, uint256 amount);

    // 变量定义
    MoodNft public immutable i_moodNft;
    IERC20 private s_linkToken;
    bytes32 private s_lastReceivedMessageId;
    string private s_lastReceivedText;
    mapping(uint64 => bool) public allowlistedDestinationChains;
    mapping(uint64 => bool) public allowlistedSourceChains;
    mapping(address => bool) public allowlistedSenders;
    mapping(uint256 tokenId => bool) public lockedNft;

    // 事件定义
    event MessageSent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address receiver,
        bytes data,
        address feeToken,
        uint256 fees
    );
    event NftLocked(address indexed sender, uint256 indexed tokenId);
    event NftReleased(uint256 indexed tokenId);

    // 构造函数
    constructor(address _router, address _link, address _moodNft) CCIPReceiver(_router) {
        s_linkToken = IERC20(_link);
        i_moodNft = MoodNft(_moodNft);
    }

    // 接收以太币的回退函数
    receive() external payable {}
    fallback() external payable {}

    // 外部函数
    function allowlistDestinationChain(uint64 _destinationChainSelector, bool allowed) external onlyOwner;
    function allowlistSourceChain(uint64 _sourceChainSelector, bool allowed) external onlyOwner;
    function allowlistSender(address _sender, bool allowed) external onlyOwner;
    function lockAndSendNft(
        uint256 tokenId,
        address newOwner,
        uint64 destinationChainSelector,
        address receiver,
        address feeTokenAddress
    ) external returns (bytes32 messageId);

    // 公共函数
    function withdraw(address _beneficiary) external onlyOwner;
    function withdrawToken(address _beneficiary, address _token) external onlyOwner;
    function getLastReceivedMessageDetails() external view returns (bytes32 messageId, string memory text);

    // 内部函数
    function sendMessagePayLINK(uint64 _destinationChainSelector, address _receiver, bytes memory _data)
        internal
        onlyAllowlistedDestinationChain(_destinationChainSelector)
        validateReceiver(_receiver)
        returns (bytes32 messageId);
    function sendMessagePayNative(uint64 _destinationChainSelector, address _receiver, bytes memory _data)
        internal
        onlyAllowlistedDestinationChain(_destinationChainSelector)
        validateReceiver(_receiver)
        returns (bytes32 messageId);
    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override;
    function _buildCCIPMessage(address _receiver, bytes memory _data, address _feeTokenAddress)
        private
        pure
        returns (Client.EVM2AnyMessage memory);
}
```

### WMNftPoolMintAndBurn.sol

```javascript

contract WMNftPoolMintAndBurn is CCIPReceiver, OwnerIsCreator {
    using SafeERC20 for IERC20;

    // 错误定义
    error WMNftPoolMintAndBurn__DestinationChainNotAllowlisted(uint64 destinationChainSelector);
    error WMNftPoolMintAndBurn__SourceChainNotAllowed(uint64 sourceChainSelector);
    error WMNftPoolMintAndBurn__SenderNotAllowed(address sender);
    error WMNftPoolMintAndBurn__InvalidReceiverAddress();
    error WMNftPoolMintAndBurn__NotEnoughBalance(uint256 balance, uint256 required);
    error WMNftPoolMintAndBurn__NothingToWithdraw();
    error WMNftPoolMintAndBurn__FailedToWithdrawEth(address sender, address beneficiary, uint256 amount);

    // 变量定义
    WMoodNft public immutable i_wmoodNft;
    IERC20 private immutable i_linkToken;
    bytes32 private s_lastReceivedMessageId;
    string private s_lastReceivedText;
    mapping(uint64 => bool) public allowlistedDestinationChains;
    mapping(uint64 => bool) public allowlistedSourceChains;
    mapping(address => bool) public allowlistedSenders;

    // 事件定义
    event MessageSent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address receiver,
        bytes data,
        address feeToken,
        uint256 fees
    );
    event NftMinted(address indexed receiver, uint256 indexed tokenId);
    event NftBurned(uint256 indexed tokenId);

    // 构造函数
    constructor(address _router, address _link, address _moodNft) CCIPReceiver(_router) {
        i_linkToken = IERC20(_link);
        i_wmoodNft = WMoodNft(_moodNft);
    }

    // 接收以太币的回退函数
    receive() external payable {}
    fallback() external payable {}

    // 外部函数
    function ccipReceive(Client.Any2EVMMessage calldata any2EvmMessage)
        external
        override
        onlyRouter
        onlyAllowlisted(any2EvmMessage.sourceChainSelector, abi.decode(any2EvmMessage.sender, (address)));
    function allowlistDestinationChain(uint64 _destinationChainSelector, bool allowed) external onlyOwner;
    function allowlistSourceChain(uint64 _sourceChainSelector, bool allowed) external onlyOwner;
    function allowlistSender(address _sender, bool allowed) external onlyOwner;
    function burnAndSendNft(
        uint256 tokenId,
        address newOwner,
        uint64 destinationChainSelector,
        address receiver,
        IERC20 feeTokenAddress
    ) external;

    // 公共函数
    function withdraw(address _beneficiary) public onlyOwner;
    function withdrawToken(address _beneficiary, address _token) public onlyOwner;
    function getLastReceivedMessageDetails() public view returns (bytes32 messageId, string memory text);
    function buildCCIPMessage(address _receiver, bytes memory _data, address _feeTokenAddress)
        external
        pure
        returns (Client.EVM2AnyMessage memory evm2AnyMessage);

    // 内部函数
    function sendMessagePay(
        uint64 _destinationChainSelector,
        address _receiver,
        bytes memory _data,
        IERC20 feeTokenAddress
    )
        internal
        onlyAllowlistedDestinationChain(_destinationChainSelector)
        validateReceiver(_receiver)
        returns (bytes32 messageId);
    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override;
    function _buildCCIPMessage(address _receiver, bytes memory _data, address _feeTokenAddress)
        private
        pure
        returns (Client.EVM2AnyMessage memory);
}
```

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
