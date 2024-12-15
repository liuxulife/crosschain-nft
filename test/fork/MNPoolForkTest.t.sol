//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MoodNft} from "src/MoodNft.sol";
import {MNftPoolLockAndRelease} from "src/MNftPoolLockAndRelease.sol";
import {DeployMNftPool} from "script/deploy/DeployMNftPool.s.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MNPoolForkTest is Test {
    MNftPoolLockAndRelease public mnftPool;
    DeployMNftPool public deployMNftPool;
    MoodNft public moodNft;

    uint256 public sourceFork;
    uint256 public destinationFork;

    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;

    IRouterClient public router;
    IERC20 public sourceLinkToken;

    uint64 public destinationChainSelector;

    address public USER;

    function setUp() public {
        USER = makeAddr("USER");

        string memory ETH_SEPOLIA_RPC_URL = vm.envString("ETH_SEPOLIA_RPC_URL");
        string memory ARB_SEPOLIA_RPC_URL = vm.envString("ARB_SEPOLIA_RPC_URL");

        sourceFork = vm.createFork(ETH_SEPOLIA_RPC_URL);
        destinationFork = vm.createSelectFork(ARB_SEPOLIA_RPC_URL);

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        Register.NetworkDetails memory destnationNetworkDetails =
            ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        destinationChainSelector = destnationNetworkDetails.chainSelector;

        vm.selectFork(sourceFork);
        Register.NetworkDetails memory sourceNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        sourceLinkToken = IERC20(sourceNetworkDetails.linkAddress);
        router = IRouterClient(sourceNetworkDetails.routerAddress);

        ccipLocalSimulatorFork.requestLinkFromFaucet(USER, 20 ether);
        vm.deal(USER, 20 ether);
        deployMNftPool = new DeployMNftPool();
        (mnftPool, moodNft) = deployMNftPool.run();
    }

    modifier addDestChain() {
        vm.startPrank(mnftPool.owner());
        mnftPool.allowlistDestinationChain(destinationChainSelector, true);
        vm.stopPrank();
        _;
    }

    modifier prepareToUser() {
        vm.selectFork(sourceFork);
        vm.startPrank(USER);
        console.log("USER balance: ", USER.balance);
        // (bool success,) = address(mnftPool).call{value: 5 ether}("");
        payable(address(mnftPool)).transfer(1 ether);

        sourceLinkToken.transfer(address(mnftPool), 5 ether);

        moodNft.mintNft();
        moodNft.approve(address(mnftPool), 0);
        vm.stopPrank();
        _;
    }

    function testLockAndSendNftFork() public addDestChain prepareToUser {
        assert(moodNft.ownerOf(0) == USER);

        vm.prank(USER);
        mnftPool.lockAndSendNft(0, USER, destinationChainSelector, USER, address(sourceLinkToken));

        assert(moodNft.ownerOf(0) == address(mnftPool));
        assert(mnftPool.lockedNft(0) == true);
    }

    function testCanEmitNftLockedFork() public addDestChain prepareToUser {
        vm.startPrank(USER);
        vm.expectEmit(true, true, false, false);
        emit MNftPoolLockAndRelease.NftLocked(USER, 0);
        mnftPool.lockAndSendNft(0, USER, destinationChainSelector, USER, address(sourceLinkToken));
        vm.stopPrank();
    }

    function testPayByLinkFork() public addDestChain prepareToUser {
        uint256 startingLinkBalance = sourceLinkToken.balanceOf(address(mnftPool));
        vm.startPrank(USER);
        mnftPool.lockAndSendNft(0, USER, destinationChainSelector, USER, address(sourceLinkToken));
        uint256 endingLinkBalance = sourceLinkToken.balanceOf(address(mnftPool));
        assert(startingLinkBalance > endingLinkBalance);
        vm.stopPrank();
    }

    function testPayByETHFork() public addDestChain prepareToUser {
        uint256 startingLinkBalance = sourceLinkToken.balanceOf(address(mnftPool));
        vm.startPrank(USER);
        mnftPool.lockAndSendNft(0, USER, destinationChainSelector, USER, address(0));
        uint256 endingLinkBalance = sourceLinkToken.balanceOf(address(mnftPool));
        assert(startingLinkBalance == endingLinkBalance);
        vm.stopPrank();
    }

    function testInvalidReceiverAddressFork() public addDestChain prepareToUser {
        vm.expectRevert(MNftPoolLockAndRelease.MNftPoolLockAndRelease__InvalidReceiverAddress.selector);
        vm.startPrank(USER);
        mnftPool.lockAndSendNft(0, USER, destinationChainSelector, address(0), address(sourceLinkToken));
        vm.stopPrank();
    }

    function testFailedToWithdrawEthFork() public {
        vm.selectFork(sourceFork);
        vm.deal(address(mnftPool), 1 ether);
        vm.mockCall(address(USER), abi.encodeWithSelector(0), abi.encode(false));
        vm.expectRevert(
            abi.encodeWithSelector(
                MNftPoolLockAndRelease.MNftPoolLockAndRelease__FailedToWithdrawEth.selector, USER, 1 ether
            )
        );
        vm.startPrank(mnftPool.owner());
        mnftPool.withdraw(USER);
        vm.stopPrank();
        vm.clearMockedCalls();
    }

    //////////////////////////////////////////
    /////// Test ccipReceive        //////////
    //////////////////////////////////////////

    modifier prepareForReceive() {
        vm.selectFork(sourceFork);
        vm.startPrank(mnftPool.owner());
        mnftPool.allowlistSourceChain(destinationChainSelector, true);
        mnftPool.allowlistSender(USER, true);
        vm.stopPrank();
        _;
    }

    function prepareScenario() public returns (Client.EVMTokenAmount[] memory tokensToSendDetails) {
        vm.startPrank(USER);

        tokensToSendDetails = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenToSendDetails =
            Client.EVMTokenAmount({token: address(sourceLinkToken), amount: 0});
        tokensToSendDetails[0] = tokenToSendDetails;

        vm.stopPrank();
        return tokensToSendDetails;
    }

    function testRevertInvalidRouterFork() public prepareForReceive {
        Client.EVMTokenAmount[] memory tokensToSendDetails = prepareScenario();

        Client.Any2EVMMessage memory any2EvmMessage = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: destinationChainSelector,
            sender: abi.encode(USER),
            data: abi.encode(0, USER),
            destTokenAmounts: tokensToSendDetails
        });
        // vm.prank(mNftPoolLockAndRelease.getRouter());  // this is the mNftPoolLockAndRelease router, if prank, it not revert.
        vm.prank(USER);
        vm.expectRevert();
        mnftPool.ccipReceive(any2EvmMessage);
    }

    function testCanRevertIfNotAllowedSourceChainFork() public {
        vm.selectFork(destinationFork);
        Client.EVMTokenAmount[] memory tokensToSendDetails = prepareScenario();

        Client.Any2EVMMessage memory any2EvmMessage = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: destinationChainSelector,
            sender: abi.encode(USER),
            data: abi.encode(0, USER),
            destTokenAmounts: tokensToSendDetails
        });

        vm.selectFork(sourceFork);
        vm.startPrank(mnftPool.owner());
        mnftPool.allowlistSender(USER, true);
        vm.stopPrank();

        vm.prank(mnftPool.getRouter());
        vm.expectRevert(
            abi.encodeWithSelector(
                MNftPoolLockAndRelease.MNftPoolLockAndRelease__SourceChainNotAllowed.selector, destinationChainSelector
            )
        );
        mnftPool.ccipReceive(any2EvmMessage);
    }

    function testCanRevertIfNotAllowedSenderFork() public {
        vm.selectFork(destinationFork);
        Client.EVMTokenAmount[] memory tokensToSendDetails = prepareScenario();

        Client.Any2EVMMessage memory any2EvmMessage = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: destinationChainSelector,
            sender: abi.encode(USER),
            data: abi.encode(0, USER),
            destTokenAmounts: tokensToSendDetails
        });

        vm.selectFork(sourceFork);
        vm.startPrank(mnftPool.owner());
        mnftPool.allowlistSourceChain(destinationChainSelector, true);
        mnftPool.allowlistSender(USER, false);
        vm.stopPrank();

        vm.prank(mnftPool.getRouter());
        vm.expectRevert(
            abi.encodeWithSelector(MNftPoolLockAndRelease.MNftPoolLockAndRelease__SenderNotAllowed.selector, USER)
        );
        mnftPool.ccipReceive(any2EvmMessage);
    }

    function testCCIPReceiveFork() public addDestChain prepareToUser prepareForReceive {
        // 1. lock nft
        // 2. receive message
        // 3. unlock nft
        vm.startPrank(USER);
        mnftPool.lockAndSendNft(0, USER, destinationChainSelector, USER, address(sourceLinkToken));
        vm.stopPrank();

        Client.EVMTokenAmount[] memory tokensToSendDetails = prepareScenario();

        Client.Any2EVMMessage memory any2EvmMessage = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: destinationChainSelector,
            sender: abi.encode(USER),
            data: abi.encode(0, USER),
            destTokenAmounts: tokensToSendDetails
        });

        vm.startPrank(mnftPool.getRouter());
        vm.expectEmit(true, false, false, false);
        emit MNftPoolLockAndRelease.NftReleased(0);

        mnftPool.ccipReceive(any2EvmMessage);
        vm.stopPrank();
        assert(moodNft.balanceOf(USER) == 1);
        assert(moodNft.balanceOf(address(mnftPool)) == 0);
        assert(moodNft.ownerOf(0) == USER);
    }
}
