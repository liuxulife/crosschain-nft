//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MoodNft} from "src/MoodNft.sol";
import {MNftPoolLockAndRelease} from "src/MNftPoolLockAndRelease.sol";
import {DeployMNftPool} from "script/deploy/DeployMNftPool.s.sol";
import {CCIPLocalSimulator, IRouterClient, LinkToken} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

contract MNftPoolTest is Test {
    CCIPLocalSimulator public ccipLocalSimulator;
    DeployMNftPool public deployMNftPool;
    MoodNft public moodNft;
    MNftPoolLockAndRelease public mNftPoolLockAndRelease;

    IRouterClient public destChainRouter;
    LinkToken public linkToken;
    uint64 public chainSelector;

    address USER = makeAddr("user");

    function setUp() public {
        ccipLocalSimulator = new CCIPLocalSimulator();
        (uint64 _chainSelector,, IRouterClient _destChainRouter,, LinkToken _linkToken,,) =
            ccipLocalSimulator.configuration();

        chainSelector = _chainSelector;
        destChainRouter = _destChainRouter;
        linkToken = _linkToken;

        ccipLocalSimulator.requestLinkFromFaucet(USER, 1 ether);
        vm.deal(USER, 5 ether);

        deployMNftPool = new DeployMNftPool();
        mNftPoolLockAndRelease = deployMNftPool.run();

        moodNft = deployMNftPool.moodNft();
    }

    modifier addDestChain() {
        vm.startPrank(mNftPoolLockAndRelease.owner());
        mNftPoolLockAndRelease.allowlistDestinationChain(chainSelector, true);
        vm.stopPrank();
        _;
    }

    modifier prepareToUser() {
        vm.startPrank(USER);
        linkToken.transfer(address(mNftPoolLockAndRelease), 1 ether);
        // (bool success,) = address(mNftPoolLockAndRelease).call{value: 1 ether}("");
        payable(address(mNftPoolLockAndRelease)).transfer(1 ether);
        moodNft.mintNft();
        moodNft.approve(address(mNftPoolLockAndRelease), 0);
        // moodNft.approve(USER, 0);
        vm.stopPrank();
        _;
    }

    modifier prepareToUserLockedByLink() {
        vm.startPrank(USER);
        mNftPoolLockAndRelease.lockAndSendNft(0, USER, chainSelector, USER, address(linkToken));
        vm.stopPrank();
        _;
    }

    modifier prepareToUserLockedByNative() {
        vm.startPrank(USER);
        mNftPoolLockAndRelease.lockAndSendNft(0, USER, chainSelector, USER, address(0));
        vm.stopPrank();
        _;
    }

    //////////////////////////////////////////
    /////////// Test LockAndSendNft //////////
    //////////////////////////////////////////

    function testLockAndSendNft() public addDestChain prepareToUser {
        assert(moodNft.ownerOf(0) == USER);

        vm.prank(USER);
        mNftPoolLockAndRelease.lockAndSendNft(0, USER, chainSelector, USER, address(linkToken));

        assert(moodNft.ownerOf(0) == address(mNftPoolLockAndRelease));
        assert(mNftPoolLockAndRelease.lockedNft(0) == true);
    }

    function testCanEmitNftLocked() public addDestChain prepareToUser {
        vm.startPrank(USER);
        vm.expectEmit(true, true, false, false);
        emit MNftPoolLockAndRelease.NftLocked(USER, 0);
        mNftPoolLockAndRelease.lockAndSendNft(0, USER, chainSelector, USER, address(linkToken));
        vm.stopPrank();
    }
    // may need fuzz test ?
    // function testPayByWhat(address feeTokenAddress) public prepareToUser addDestChain {
    //     uint256 startingLinkBalance = linkToken.balanceOf(address(mNftPoolLockAndRelease));
    //     vm.startPrank(USER);
    //     if (feeTokenAddress == address(0)) {
    //         mNftPoolLockAndRelease.lockAndSendNft(0, USER, chainSelector, USER, feeTokenAddress);
    //         uint256 endingLinkBalance = linkToken.balanceOf(address(mNftPoolLockAndRelease));
    //         assert(startingLinkBalance == endingLinkBalance);
    //     } else {
    //         mNftPoolLockAndRelease.lockAndSendNft(0, USER, chainSelector, USER, feeTokenAddress);

    //         uint256 endingLinkBalance = linkToken.balanceOf(address(mNftPoolLockAndRelease));
    //         assert(startingLinkBalance > endingLinkBalance);
    //     }
    //     vm.stopPrank();
    // }

    // @?Due to local simulator, it not use fee, fee is 0
    function testPayByLink() public addDestChain prepareToUser {
        uint256 startingLinkBalance = linkToken.balanceOf(address(mNftPoolLockAndRelease));
        vm.startPrank(USER);
        mNftPoolLockAndRelease.lockAndSendNft(0, USER, chainSelector, USER, address(linkToken));
        uint256 endingLinkBalance = linkToken.balanceOf(address(mNftPoolLockAndRelease));
        assert(startingLinkBalance >= endingLinkBalance);
        vm.stopPrank();
    }

    function testPayByETH() public addDestChain prepareToUser {
        uint256 startingLinkBalance = linkToken.balanceOf(address(mNftPoolLockAndRelease));
        vm.startPrank(USER);
        mNftPoolLockAndRelease.lockAndSendNft(0, USER, chainSelector, USER, address(0));
        uint256 endingLinkBalance = linkToken.balanceOf(address(mNftPoolLockAndRelease));
        assert(startingLinkBalance == endingLinkBalance);
        vm.stopPrank();
    }

    function testInvalidReceiverAddress() public addDestChain prepareToUser {
        vm.expectRevert(MNftPoolLockAndRelease.MNftPoolLockAndRelease__InvalidReceiverAddress.selector);
        vm.startPrank(USER);
        mNftPoolLockAndRelease.lockAndSendNft(0, USER, chainSelector, address(0), address(linkToken));
        vm.stopPrank();
    }

    function testUnAllowedDestChain() public prepareToUser {
        vm.expectRevert(
            abi.encodeWithSelector(
                MNftPoolLockAndRelease.MNftPoolLockAndRelease__DestinationChainNotAllowlisted.selector, chainSelector
            )
        );
        vm.startPrank(USER);
        mNftPoolLockAndRelease.lockAndSendNft(0, USER, chainSelector, USER, address(0));
        vm.stopPrank();
    }

    //////////////////////////////////////////
    /////////// Test Withdraw       //////////
    //////////////////////////////////////////
    function testWithdrawIfNotOwner() public {
        vm.expectRevert("Only callable by owner");
        vm.startPrank(USER);
        mNftPoolLockAndRelease.withdraw(USER);
        vm.stopPrank();
    }

    function testWithdrawTokenIfNotOwner() public {
        vm.expectRevert("Only callable by owner");
        vm.startPrank(USER);
        mNftPoolLockAndRelease.withdrawToken(USER, address(linkToken));
        vm.stopPrank();
    }

    function testNotingToWithdraw() public {
        vm.startPrank(mNftPoolLockAndRelease.owner());
        vm.expectRevert(MNftPoolLockAndRelease.MNftPoolLockAndRelease__NothingToWithdraw.selector);
        mNftPoolLockAndRelease.withdraw(USER);
        vm.stopPrank();
    }

    function testFailedToWithdrawEth() public {
        vm.deal(address(mNftPoolLockAndRelease), 1 ether);
        vm.mockCall(address(USER), abi.encodeWithSelector(0), abi.encode(false));
        vm.expectRevert(
            abi.encodeWithSelector(
                MNftPoolLockAndRelease.MNftPoolLockAndRelease__FailedToWithdrawEth.selector, USER, 1 ether
            )
        );
        vm.startPrank(mNftPoolLockAndRelease.owner());
        mNftPoolLockAndRelease.withdraw(USER);
        vm.stopPrank();
        vm.clearMockedCalls();
    }

    function testWithdrawToken() public addDestChain prepareToUser prepareToUserLockedByLink {
        vm.startPrank(mNftPoolLockAndRelease.owner());
        mNftPoolLockAndRelease.withdraw(USER);
        vm.stopPrank();
        assert(address(mNftPoolLockAndRelease).balance == 0);
    }

    function testWithdrawLinkToken() public addDestChain prepareToUser prepareToUserLockedByNative {
        vm.startPrank(mNftPoolLockAndRelease.owner());
        mNftPoolLockAndRelease.withdrawToken(USER, address(linkToken));
        vm.stopPrank();
        assert(linkToken.balanceOf(address(mNftPoolLockAndRelease)) == 0);
    }

    //////////////////////////////////////////
    /////////// Test AllowDestChain  //////////
    //////////////////////////////////////////

    function testNotOwnerCanNotAllowDestChain() public {
        vm.expectRevert("Only callable by owner");
        vm.startPrank(USER);
        mNftPoolLockAndRelease.allowlistDestinationChain(chainSelector, true);
        vm.stopPrank();
    }

    function testAllowDestChain() public {
        vm.startPrank(mNftPoolLockAndRelease.owner());
        mNftPoolLockAndRelease.allowlistDestinationChain(chainSelector, true);
        vm.stopPrank();
        assert(mNftPoolLockAndRelease.allowlistedDestinationChains(chainSelector));
    }

    //////////////////////////////////////////
    /////// Test AllowSourceChain  //////////
    //////////////////////////////////////////

    function testNotOwnerCanNotAllowSourceChain() public {
        vm.expectRevert("Only callable by owner");
        vm.startPrank(USER);
        mNftPoolLockAndRelease.allowlistSourceChain(chainSelector, true);
        vm.stopPrank();
    }

    function testAllowSourceChain() public {
        vm.startPrank(mNftPoolLockAndRelease.owner());
        mNftPoolLockAndRelease.allowlistSourceChain(chainSelector, true);
        vm.stopPrank();
        assert(mNftPoolLockAndRelease.allowlistedSourceChains(chainSelector));
    }

    //////////////////////////////////////////
    /////// Test Allow Senders      //////////
    //////////////////////////////////////////
    function testNotOwnerCanNotAllowSender() public {
        vm.expectRevert("Only callable by owner");
        vm.startPrank(USER);
        mNftPoolLockAndRelease.allowlistSender(USER, true);
        vm.stopPrank();
    }

    function testAllowSender() public {
        vm.startPrank(mNftPoolLockAndRelease.owner());
        mNftPoolLockAndRelease.allowlistSender(USER, true);
        vm.stopPrank();
        assert(mNftPoolLockAndRelease.allowlistedSenders(USER));
    }

    //////////////////////////////////////////
    /////// Test ccipReceive        //////////
    //////////////////////////////////////////

    modifier prepareForReceive() {
        vm.startPrank(mNftPoolLockAndRelease.owner());
        mNftPoolLockAndRelease.allowlistSourceChain(chainSelector, true);
        mNftPoolLockAndRelease.allowlistSender(USER, true);
        vm.stopPrank();
        _;
    }

    function prepareScenario() public returns (Client.EVMTokenAmount[] memory tokensToSendDetails) {
        vm.startPrank(USER);

        tokensToSendDetails = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenToSendDetails = Client.EVMTokenAmount({token: address(linkToken), amount: 0});
        tokensToSendDetails[0] = tokenToSendDetails;

        vm.stopPrank();
        return tokensToSendDetails;
    }

    function testRevertInvalidRouter() public prepareForReceive {
        Client.EVMTokenAmount[] memory tokensToSendDetails = prepareScenario();

        Client.Any2EVMMessage memory any2EvmMessage = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: chainSelector,
            sender: abi.encode(USER),
            data: abi.encode(0, USER),
            destTokenAmounts: tokensToSendDetails
        });
        // vm.prank(mNftPoolLockAndRelease.getRouter());  // this is the mNftPoolLockAndRelease router, if prank, it not revert.
        vm.prank(USER);
        vm.expectRevert();
        mNftPoolLockAndRelease.ccipReceive(any2EvmMessage);
    }

    function testCanRevertIfNotAllowedSourceChain() public {
        vm.startPrank(mNftPoolLockAndRelease.owner());
        mNftPoolLockAndRelease.allowlistSender(USER, true);
        vm.stopPrank();
        Client.EVMTokenAmount[] memory tokensToSendDetails = prepareScenario();

        Client.Any2EVMMessage memory any2EvmMessage = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: chainSelector,
            sender: abi.encode(USER),
            data: abi.encode(0, USER),
            destTokenAmounts: tokensToSendDetails
        });

        vm.prank(mNftPoolLockAndRelease.getRouter());
        vm.expectRevert(
            abi.encodeWithSelector(
                MNftPoolLockAndRelease.MNftPoolLockAndRelease__SourceChainNotAllowed.selector, chainSelector
            )
        );
        mNftPoolLockAndRelease.ccipReceive(any2EvmMessage);
    }

    function testCanRevertIfNotAllowedSender() public {
        vm.startPrank(mNftPoolLockAndRelease.owner());
        mNftPoolLockAndRelease.allowlistSourceChain(chainSelector, true);
        mNftPoolLockAndRelease.allowlistSender(USER, false);
        vm.stopPrank();
        Client.EVMTokenAmount[] memory tokensToSendDetails = prepareScenario();

        Client.Any2EVMMessage memory any2EvmMessage = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: chainSelector,
            sender: abi.encode(USER),
            data: abi.encode(0, USER),
            destTokenAmounts: tokensToSendDetails
        });

        vm.prank(mNftPoolLockAndRelease.getRouter());
        vm.expectRevert(
            abi.encodeWithSelector(MNftPoolLockAndRelease.MNftPoolLockAndRelease__SenderNotAllowed.selector, USER)
        );
        mNftPoolLockAndRelease.ccipReceive(any2EvmMessage);
    }

    function testCCIPReceive() public addDestChain prepareToUser prepareForReceive {
        // 1. lock nft
        // 2. receive message
        // 3. unlock nft
        vm.startPrank(USER);
        mNftPoolLockAndRelease.lockAndSendNft(0, USER, chainSelector, USER, address(linkToken));
        vm.stopPrank();

        Client.EVMTokenAmount[] memory tokensToSendDetails = prepareScenario();

        Client.Any2EVMMessage memory any2EvmMessage = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: chainSelector,
            sender: abi.encode(USER),
            data: abi.encode(0, USER),
            destTokenAmounts: tokensToSendDetails
        });

        vm.startPrank(mNftPoolLockAndRelease.getRouter());
        vm.expectEmit(true, false, false, false);
        emit MNftPoolLockAndRelease.NftReleased(0);

        mNftPoolLockAndRelease.ccipReceive(any2EvmMessage);
        vm.stopPrank();
        assert(moodNft.balanceOf(USER) == 1);
        assert(moodNft.balanceOf(address(mNftPoolLockAndRelease)) == 0);
        assert(moodNft.ownerOf(0) == USER);
    }
}
