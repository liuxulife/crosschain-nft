// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MoodNft} from "src/MoodNft.sol";

/// @title - A Nft Pool contract for locking and releasing NFTs across chains.
contract MNftPoolLockAndRelease is CCIPReceiver, OwnerIsCreator {
    using SafeERC20 for IERC20;

    //////////////////////////////////////////
    /////////// errors           /////////////
    //////////////////////////////////////////
    error MNftPoolLockAndRelease__DestinationChainNotAllowlisted(uint64 destinationChainSelector);
    error MNftPoolLockAndRelease__SourceChainNotAllowed(uint64 sourceChainSelector);
    error MNftPoolLockAndRelease__SenderNotAllowed(address sender);
    error MNftPoolLockAndRelease__InvalidReceiverAddress();
    error MNftPoolLockAndRelease__NotEnoughBalance(uint256 balance, uint256 required);
    error MNftPoolLockAndRelease__NothingToWithdraw();
    error MNftPoolLockAndRelease__FailedToWithdrawEth(address sender, address beneficiary, uint256 amount);

    //////////////////////////////////////////
    /////////// variables        /////////////
    //////////////////////////////////////////

    MoodNft public immutable i_moodNft;
    IERC20 private s_linkToken;

    bytes32 private s_lastReceivedMessageId;
    string private s_lastReceivedText;

    // Mapping to keep track of allowlisted destination chains.
    mapping(uint64 => bool) public allowlistedDestinationChains;

    // Mapping to keep track of allowlisted source chains.
    mapping(uint64 => bool) public allowlistedSourceChains;

    // Mapping to keep track of allowlisted senders.
    mapping(address => bool) public allowlistedSenders;

    mapping(uint256 tokenId => bool) public lockedNft;

    //////////////////////////////////////////
    /////////// events          /////////////
    //////////////////////////////////////////
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

    //////////////////////////////////////////
    /////////// modifiers        /////////////
    //////////////////////////////////////////

    /**
     * @dev Modifier that checks if the chain with the given destinationChainSelector is allowlisted.
     * @param _destinationChainSelector The selector of the destination chain.
     */
    modifier onlyAllowlistedDestinationChain(uint64 _destinationChainSelector) {
        if (!allowlistedDestinationChains[_destinationChainSelector]) {
            revert MNftPoolLockAndRelease__DestinationChainNotAllowlisted(_destinationChainSelector);
        }
        _;
    }

    /**
     *   @dev Modifier that checks if the chain with the given sourceChainSelector is allowlisted and if the sender is allowlisted.
     *  @param _sourceChainSelector The selector of the destination chain.
     *  @param _sender The address of the sender.
     */
    modifier onlyAllowlisted(uint64 _sourceChainSelector, address _sender) {
        if (!allowlistedSourceChains[_sourceChainSelector]) {
            revert MNftPoolLockAndRelease__SourceChainNotAllowed(_sourceChainSelector);
        }
        if (!allowlistedSenders[_sender]) revert MNftPoolLockAndRelease__SenderNotAllowed(_sender);
        _;
    }

    /**
     *  @dev Modifier that checks the receiver address is not 0.
     *  @param _receiver The receiver address.
     */
    modifier validateReceiver(address _receiver) {
        if (_receiver == address(0)) revert MNftPoolLockAndRelease__InvalidReceiverAddress();
        _;
    }

    //////////////////////////////////////////
    //////// constructor & fallback //////////
    //////////////////////////////////////////

    constructor(address _router, address _link, address _moodNft) CCIPReceiver(_router) {
        s_linkToken = IERC20(_link);
        i_moodNft = MoodNft(_moodNft);
    }

    /**
     *  @notice Fallback function to allow the contract to receive Ether.
     *  @dev This function has no function body, making it a default function for receiving Ether.
     *  It is automatically called when Ether is sent to the contract without any data.
     */
    receive() external payable {}
    fallback() external payable {}

    //////////////////////////////////////////
    /////////// external functions ///////////
    //////////////////////////////////////////

    /**
     *  @dev Updates the allowlist status of a destination chain for transactions.
     *  @notice This function can only be called by the owner.
     *  @param _destinationChainSelector The selector of the destination chain to be updated.
     *  @param allowed The allowlist status to be set for the destination chain.
     */
    function allowlistDestinationChain(uint64 _destinationChainSelector, bool allowed) external onlyOwner {
        allowlistedDestinationChains[_destinationChainSelector] = allowed;
    }

    /**
     * / @dev Updates the allowlist status of a source chain
     * / @notice This function can only be called by the owner.
     * / @param _sourceChainSelector The selector of the source chain to be updated.
     * / @param allowed The allowlist status to be set for the source chain.
     */
    function allowlistSourceChain(uint64 _sourceChainSelector, bool allowed) external onlyOwner {
        allowlistedSourceChains[_sourceChainSelector] = allowed;
    }

    /**
     * / @dev Updates the allowlist status of a sender for transactions.
     * / @notice This function can only be called by the owner.
     * / @param _sender The address of the sender to be updated.
     * / @param allowed The allowlist status to be set for the sender.
     */
    function allowlistSender(address _sender, bool allowed) external onlyOwner {
        allowlistedSenders[_sender] = allowed;
    }

    /**
     *
     * @param tokenId  the id of the NFT to be locked
     * @param newOwner  the address of the new owner of the NFT
     * @param destinationChainSelector  the selector of the destination chain
     * @param receiver   the address of the receiver on the destination chain
     * @param feeTokenAddress  the address of the token to be used for fees
     */
    function lockAndSendNft(
        uint256 tokenId,
        address newOwner,
        uint64 destinationChainSelector,
        address receiver,
        address feeTokenAddress
    ) external returns (bytes32 messageId) {
        i_moodNft.transferFrom(msg.sender, address(this), tokenId);
        bytes memory dataload = abi.encode(tokenId, newOwner);

        if (feeTokenAddress == address(0)) {
            messageId = sendMessagePayNative(destinationChainSelector, receiver, dataload);
        } else {
            messageId = sendMessagePayLINK(destinationChainSelector, receiver, dataload);
        }

        lockedNft[tokenId] = true;
        emit NftLocked(msg.sender, tokenId);
        return messageId;
    }

    //////////////////////////////////////////
    /////////// public functions /////////////
    //////////////////////////////////////////
    /**
     * / @notice Allows the contract owner to withdraw the entire balance of Ether from the contract.
     * / @dev This function reverts if there are no funds to withdraw or if the transfer fails.
     * / It should only be callable by the owner of the contract.
     * / @param _beneficiary The address to which the Ether should be sent.
     */
    function withdraw(address _beneficiary) external onlyOwner {
        // Retrieve the balance of this contract
        uint256 amount = address(this).balance;

        // Revert if there is nothing to withdraw
        if (amount == 0) revert MNftPoolLockAndRelease__NothingToWithdraw();

        // Attempt to send the funds, capturing the success status and discarding any return data
        (bool sent,) = _beneficiary.call{value: amount}("");

        // Revert if the send failed, with information about the attempted transfer
        if (!sent) revert MNftPoolLockAndRelease__FailedToWithdrawEth(msg.sender, _beneficiary, amount);
    }

    /**
     * / @notice Allows the owner of the contract to withdraw all tokens of a specific ERC20 token.
     * / @dev This function reverts with a 'NothingToWithdraw' error if there are no tokens to withdraw.
     * / @param _beneficiary The address to which the tokens will be sent.
     * / @param _token The contract address of the ERC20 token to be withdrawn.
     */
    function withdrawToken(address _beneficiary, address _token) external onlyOwner {
        // Retrieve the balance of this contract
        uint256 amount = IERC20(_token).balanceOf(address(this));

        // Revert if there is nothing to withdraw
        if (amount == 0) revert MNftPoolLockAndRelease__NothingToWithdraw();

        IERC20(_token).safeTransfer(_beneficiary, amount);
    }

    ////////////////////////////////////////
    /////////// internal functions /////////
    ////////////////////////////////////////
    /**
     * / @notice Sends data and transfer tokens to receiver on the destination chain.
     * / @notice Pay for fees in LINK.
     * / @dev Assumes your contract has sufficient LINK to pay for CCIP fees.
     * / @param _destinationChainSelector The identifier (aka selector) for the destination blockchain.
     * / @param _receiver The address of the recipient on the destination blockchain.
     * / @param _data The string data to be sent.
     * / @return messageId The ID of the CCIP message that was sent.
     */
    function sendMessagePayLINK(uint64 _destinationChainSelector, address _receiver, bytes memory _data)
        internal
        onlyAllowlistedDestinationChain(_destinationChainSelector)
        validateReceiver(_receiver)
        returns (bytes32 messageId)
    {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        // address(linkToken) means fees are paid in LINK
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(_receiver, _data, address(s_linkToken));

        // Initialize a router client instance to interact with cross-chain router
        IRouterClient router = IRouterClient(this.getRouter());

        // Get the fee required to send the CCIP message
        uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

        if (fees > s_linkToken.balanceOf(address(this))) {
            revert MNftPoolLockAndRelease__NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);
        }

        // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
        s_linkToken.approve(address(router), fees);

        // Send the message through the router and store the returned message ID
        messageId = router.ccipSend(_destinationChainSelector, evm2AnyMessage);

        // Emit an event with message details
        emit MessageSent(messageId, _destinationChainSelector, _receiver, _data, address(s_linkToken), fees);

        // Return the message ID
        return messageId;
    }

    /**
     * / @notice Sends data and transfer tokens to receiver on the destination chain.
     * / @notice Pay for fees in native gas.
     * / @dev Assumes your contract has sufficient native gas like ETH on Ethereum or POL on Polygon.
     * / @param _destinationChainSelector The identifier (aka selector) for the destination blockchain.
     * / @param _receiver The address of the recipient on the destination blockchain.
     * / @param _data The string data to be sent.
     * / @return messageId The ID of the CCIP message that was sent.
     */
    function sendMessagePayNative(uint64 _destinationChainSelector, address _receiver, bytes memory _data)
        internal
        onlyAllowlistedDestinationChain(_destinationChainSelector)
        validateReceiver(_receiver)
        returns (bytes32 messageId)
    {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        // address(0) means fees are paid in native gas
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(_receiver, _data, address(0));

        // Initialize a router client instance to interact with cross-chain router
        IRouterClient router = IRouterClient(this.getRouter());

        // Get the fee required to send the CCIP message
        uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

        if (fees > address(this).balance) {
            revert MNftPoolLockAndRelease__NotEnoughBalance(address(this).balance, fees);
        }

        // Send the message through the router and store the returned message ID
        messageId = router.ccipSend{value: fees}(_destinationChainSelector, evm2AnyMessage);

        // Emit an event with message details
        emit MessageSent(messageId, _destinationChainSelector, _receiver, _data, address(0), fees);

        // Return the message ID
        return messageId;
    }

    /**
     * / @notice The entrypoint for the CCIP router to call. This function should
     * / never revert, all errors should be handled internally in this contract.
     * / @param any2EvmMessage The message to process.
     * / @dev Extremely important to ensure only router calls this.
     */
    function ccipReceive(Client.Any2EVMMessage memory any2EvmMessage)
        external
        override
        onlyRouter
        onlyAllowlisted(any2EvmMessage.sourceChainSelector, abi.decode(any2EvmMessage.sender, (address))) // Make sure the source chain and sender are allowlisted
    {
        _ccipReceive(any2EvmMessage);
    }

    /**
     *
     * @param any2EvmMessage The message received from the source chain.
     * @dev This function is called by the CCIP router when a message is received from another chain.
     * @dev It release the NFT to the receiver.
     */
    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override {
        s_lastReceivedMessageId = any2EvmMessage.messageId; // fetch the messageId
        s_lastReceivedText = abi.decode(any2EvmMessage.data, (string)); // abi-decoding of the sent text

        (uint256 tokenId, address newOwner) = abi.decode(any2EvmMessage.data, (uint256, address));
        require(lockedNft[tokenId], "Nft not locked");
        lockedNft[tokenId] = false;
        i_moodNft.transferFrom(address(this), newOwner, tokenId);
        emit NftReleased(tokenId);
    }

    ////////////////////////////////////////
    /////////// private functions //////////
    ////////////////////////////////////////

    /// @notice Construct a CCIP message.
    /// @dev This function will create an EVM2AnyMessage struct with all the necessary information for programmable tokens transfer.
    /// @param _receiver The address of the receiver.
    /// @param _data The data to be sent.
    /// @param _feeTokenAddress The address of the token used for fees. Set address(0) for native gas.
    /// @return Client.EVM2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message.
    function _buildCCIPMessage(address _receiver, bytes memory _data, address _feeTokenAddress)
        private
        pure
        returns (Client.EVM2AnyMessage memory)
    {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver), // ABI-encoded receiver address
            data: _data, // ABI-encoded string
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array aas no tokens are transferred // The amount and type of token being transferred
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit and allowing out-of-order execution.
                // Best Practice: For simplicity, the values are hardcoded. It is advisable to use a more dynamic approach
                // where you set the extra arguments off-chain. This allows adaptation depending on the lanes, messages,
                // and ensures compatibility with future CCIP upgrades. Read more about it here: https://docs.chain.link/ccip/best-practices#using-extraargs
                Client.EVMExtraArgsV2({
                    gasLimit: 400_000, // Gas limit for the callback on the destination chain
                    allowOutOfOrderExecution: true // Allows the message to be executed out of order relative to other messages from the same sender
                })
            ),
            // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
            feeToken: _feeTokenAddress
        });
        return evm2AnyMessage;
    }

    ////////////////////////////////////////
    /////////// view functions     /////////
    ////////////////////////////////////////
    /**
     * @notice Returns the details of the last CCIP received message.
     * @dev This function retrieves the ID, text, token address, and token amount of the last received CCIP message.
     * @return messageId The ID of the last received CCIP message.
     * @return text The text of the last received CCIP message.
     */
    function getLastReceivedMessageDetails() external view returns (bytes32 messageId, string memory text) {
        return (s_lastReceivedMessageId, s_lastReceivedText);
    }
}
