//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MoodNft} from "src/MoodNft.sol";
import {MNftPoolLockAndRelease} from "src/MNftPoolLockAndRelease.sol";
import {DeployMNftPool} from "script/DeployMNftPool.s.sol";
import {CCIPLocalSimulator, IRouterClient, LinkToken} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";

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

    function testPayByWhat() public prepareToUser addDestChain {
        address feeTokenAddress;
        uint256 startingLinkBalance = linkToken.balanceOf(address(mNftPoolLockAndRelease));
        vm.startPrank(USER);
        mNftPoolLockAndRelease.lockAndSendNft(0, USER, chainSelector, USER, feeTokenAddress);
        if (feeTokenAddress == address(0)) {
            uint256 endingLinkBalance = linkToken.balanceOf(address(mNftPoolLockAndRelease));
            assert(startingLinkBalance == endingLinkBalance);
        } else {
            uint256 endingLinkBalance = linkToken.balanceOf(address(mNftPoolLockAndRelease));
            assert(startingLinkBalance > endingLinkBalance);
        }
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
    function testIfNotOwner() public {
        vm.expectRevert("Only callable by owner");
        vm.startPrank(USER);
        mNftPoolLockAndRelease.withdraw(USER);
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
    /////// Test AllowSourceChain  //////////
    //////////////////////////////////////////

    //////////////////////////////////////////
    /////// Test Allow Senders      //////////
    //////////////////////////////////////////

    //////////////////////////////////////////
    /////// Test ccipReceive        //////////
    //////////////////////////////////////////
}
