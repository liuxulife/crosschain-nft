//SPDX-License-Identifier:MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MoodNft} from "src/MoodNft.sol";
import {MNftPoolLockAndRelease} from "src/MNftPoolLockAndRelease.sol";
import {DeployMNftPool} from "script/deploy/DeployMNftPool.s.sol";
import {WMoodNft} from "src/WMoodNft.sol";
import {WMNftPoolMintAndBurn} from "src/WMNftPoolMintAndBurn.sol";
import {DeployWrappedMNftPool} from "script/deploy/DeployWrappedMNftPool.s.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IRouterClient} from "@chainlink/local/lib/ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AllPoolForkTest
 * @author Thales Liu
 * @notice 1. use ETH_SEPOLIA as source fork, deploy moodNft, mNftPool
 *        2. use ARB_SEPOLIA as destination fork, deploy wMoodNft, wMNftPool
 */
contract AllPoolForkTest is Test {
    MoodNft public moodNft;
    WMoodNft public wMoodNft;
    MNftPoolLockAndRelease public mNftPool;
    WMNftPoolMintAndBurn public wMNftPool;

    DeployMNftPool public deployMNftPool;
    DeployWrappedMNftPool public deployWrappedMNftPool;

    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;

    IRouterClient public sourceRouter;
    IRouterClient public destinationRouter;

    IERC20 public sourceLinkToken;
    IERC20 public destinationLinkToken;

    uint256 public sourceFork;
    uint256 public destinationFork;

    uint64 public sourceChainSelector;
    uint64 public destinationChainSelector;

    address public USER;

    function setUp() public {
        USER = makeAddr("USER");
        string memory ETH_SEPOLIA_RPC_URL = vm.envString("ETH_SEPOLIA_RPC_URL");
        string memory ARB_SEPOLIA_RPC_URL = vm.envString("ARB_SEPOLIA_RPC_URL");

        sourceFork = vm.createFork(ETH_SEPOLIA_RPC_URL);
        // destinationFork = vm.createSelectFork(ARB_SEPOLIA_RPC_URL);
        destinationFork = vm.createFork(ARB_SEPOLIA_RPC_URL);

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        vm.selectFork(destinationFork);

        // deploy wMoodNft, wMNftPool on destination chain.
        Register.NetworkDetails memory destinationNetWorkDetails =
            ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        destinationChainSelector = destinationNetWorkDetails.chainSelector;
        destinationRouter = IRouterClient(destinationNetWorkDetails.routerAddress);
        destinationLinkToken = IERC20(destinationNetWorkDetails.linkAddress);

        deployWrappedMNftPool = new DeployWrappedMNftPool();
        (wMNftPool, wMoodNft) = deployWrappedMNftPool.run();

        ccipLocalSimulatorFork.requestLinkFromFaucet(USER, 20 ether);
        vm.deal(USER, 20 ether);

        // deploy moodNft, mNftPool on source chain.
        vm.selectFork(sourceFork);
        Register.NetworkDetails memory sourceNetWorkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        sourceChainSelector = sourceNetWorkDetails.chainSelector;
        sourceRouter = IRouterClient(sourceNetWorkDetails.routerAddress);
        sourceLinkToken = IERC20(sourceNetWorkDetails.linkAddress);

        deployMNftPool = new DeployMNftPool();
        (mNftPool, moodNft) = deployMNftPool.run();

        ccipLocalSimulatorFork.requestLinkFromFaucet(USER, 20 ether);
        vm.deal(USER, 20 ether);
    }

    modifier onSourceChainAllowDestAndSourceChain() {
        vm.selectFork(sourceFork);
        vm.startPrank(mNftPool.owner());
        mNftPool.allowlistDestinationChain(destinationChainSelector, true);
        mNftPool.allowlistSourceChain(destinationChainSelector, true);
        _;
    }

    modifier onDestChainAllowDestAndSourceChain() {
        vm.selectFork(destinationFork);

        vm.startPrank(wMNftPool.owner());
        wMNftPool.allowlistDestinationChain(sourceChainSelector, true);
        wMNftPool.allowlistSourceChain(sourceChainSelector, true);
        wMNftPool.allowlistSender(USER, true);
        _;
    }

    modifier moodNftPrepareForUser() {
        vm.selectFork(sourceFork);
        vm.startPrank(USER);
        moodNft.mintNft();
        moodNft.approve(address(mNftPool), 0);
        sourceLinkToken.transfer(address(mNftPool), 5 ether);
        payable(address(mNftPool)).transfer(5 ether);
        _;
    }

    modifier wMoodNftPrepareForUser() {
        vm.selectFork(destinationFork);
        vm.startPrank(USER);
        wMoodNft.mintNft();
        wMoodNft.approve(address(wMNftPool), 0);
        destinationLinkToken.transfer(address(wMNftPool), 5 ether);
        payable(address(wMNftPool)).transfer(5 ether);
        _;
    }

    // 1. on source chain test lock ann send message
    // 2. on destination chain test mint and receive massage
    // @notice can receive message but can not execute it.
    function testLockAndMint()
        public
        onSourceChainAllowDestAndSourceChain
        onDestChainAllowDestAndSourceChain
        moodNftPrepareForUser
    {
        vm.selectFork(sourceFork);
        vm.startPrank(USER);
        mNftPool.lockAndSendNft(0, USER, destinationChainSelector, USER, address(sourceLinkToken));
        assert(moodNft.balanceOf(USER) == 0);
        assert(moodNft.ownerOf(0) == address(mNftPool));

        ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);
        // vm.startPrank(USER);
        // sourceLinkToken.transfer(address(wMNftPool), 5 ether);
        // payable(address(wMNftPool)).transfer(5 ether);

        vm.selectFork(destinationFork);
        assert(vm.activeFork() == destinationFork);
        assert(wMoodNft.balanceOf(USER) == 1);
        // assert(wMoodNft.ownerOf(0) == USER);
    }

    // Why the source chain selector is 0?
    // function testBurnAndRelease()
    //     public
    //     onDestChainAllowDestAndSourceChain
    //     onSourceChainAllowDestAndSourceChain
    //     wMoodNftPrepareForUser
    // {
    //     vm.selectFork(destinationFork);
    //     vm.startPrank(USER);
    //     wMNftPool.burnAndSendNft(0, USER, sourceChainSelector, USER, destinationLinkToken);

    //     assert(wMoodNft.balanceOf(USER) == 0);
    //     vm.expectRevert();
    //     wMoodNft.ownerOf(0);
    //     vm.stopPrank();
    // }
}
