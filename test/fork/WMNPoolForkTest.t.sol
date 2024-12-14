//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {WMoodNft} from "src/WMoodNft.sol";
import {DeployWrappedMNftPool} from "script/deploy/DeployWrappedMNftPool.s.sol";
import {WMNftPoolMintAndBurn} from "src/WMNftPoolMintAndBurn.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";

contract WMNPoolForkTest is Test {
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    IRouterClient public router;

    uint256 public sourceFork;
    uint256 public destinationFork;

    uint64 public destinationChainSelector;
    IERC20 public sourceLinkToken;

    address public USER;

    DeployWrappedMNftPool public deployWrappedMNftPool;
    WMNftPoolMintAndBurn public wmNftPool;
    WMoodNft public wmoodNft;

    function setUp() public {
        USER = makeAddr("USER");
        vm.deal(USER, 5 ether);

        string memory ETH_SEPOLIA_RPC_URL = vm.envString("ETH_SEPOLIA_RPC_URL");
        string memory ARB_SEPOLIA_RPC_URL = vm.envString("ARB_SEPOLIA_RPC_URL");

        sourceFork = vm.createFork(ARB_SEPOLIA_RPC_URL);
        destinationFork = vm.createSelectFork(ETH_SEPOLIA_RPC_URL);

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        Register.NetworkDetails memory destinationNetWorkDetails =
            ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        destinationChainSelector = destinationNetWorkDetails.chainSelector;

        vm.selectFork(sourceFork);
        Register.NetworkDetails memory sourceNetWorkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        sourceLinkToken = IERC20(sourceNetWorkDetails.linkAddress);
        router = IRouterClient(sourceNetWorkDetails.routerAddress);

        deployWrappedMNftPool = new DeployWrappedMNftPool();
        wmNftPool = deployWrappedMNftPool.run();
        wmoodNft = deployWrappedMNftPool.wmoodNft();
        ccipLocalSimulatorFork.requestLinkFromFaucet(USER, 20 ether);
    }

    modifier addDestChain() {
        vm.selectFork(sourceFork);
        vm.startPrank(wmNftPool.owner());
        wmNftPool.allowlistDestinationChain(destinationChainSelector, true);
        vm.stopPrank();
        _;
    }

    modifier prepareToUser() {
        vm.selectFork(sourceFork);
        vm.startPrank(USER);
        sourceLinkToken.transfer(address(wmNftPool), 5 ether);
        // (bool success,) = address(mNftPoolLockAndRelease).call{value: 1 ether}("");
        // payable(address(wmNftPool)).transfer(1 ether);
        wmoodNft.mintNft();
        wmoodNft.approve(address(wmNftPool), 0);
        // moodNft.approve(USER, 0);
        vm.stopPrank();
        _;
    }

    function testBurnAndSendNftFork() public addDestChain prepareToUser {
        assert(wmoodNft.balanceOf(USER) == 1);
        assert(wmoodNft.ownerOf(0) == USER);
        vm.startPrank(USER);
        wmNftPool.burnAndSendNft(0, USER, destinationChainSelector, USER, IERC20(address(sourceLinkToken)));
        vm.stopPrank();

        assert(wmoodNft.balanceOf(USER) == 0);
        assert(wmoodNft.balanceOf(address(wmNftPool)) == 0);
        // vm.expectRevert(abi.encodeWithSelector(ERC721.ERC721NonexistentToken.selector, 0));
        vm.expectRevert();
        assert(wmoodNft.ownerOf(0) == address(0));
    }

    function testCanEmitNftBurnedFork() public addDestChain prepareToUser {
        vm.startPrank(USER);
        vm.expectEmit(true, false, false, false);
        emit WMNftPoolMintAndBurn.NftBurned(0);
        wmNftPool.burnAndSendNft(0, USER, destinationChainSelector, USER, IERC20(address(sourceLinkToken)));
        vm.stopPrank();
    }

    // /**
    //  * It has a sequence number wrong, the first ccipSend is 564, and the  ccipSend called by  burnAndSendNft sequence number is 565
    //  */
    // function testCanEmitMessageSent() public addDestChain prepareToUser {
    //     vm.startPrank(address(wmNftPool));
    //     Client.EVM2AnyMessage memory evm2AnyMessage =
    //         wmNftPool.buildCCIPMessage(USER, abi.encode(0, USER), address(sourceLinkToken));

    //     // IRouterClient router = IRouterClient(wmNftPool.getRouter());

    //     uint256 fees = router.getFee(destinationChainSelector, evm2AnyMessage);
    //     sourceLinkToken.approve(address(router), fees);
    //     bytes32 messageId = router.ccipSend(destinationChainSelector, evm2AnyMessage);

    //     vm.stopPrank();

    //     vm.startPrank(USER);
    //     vm.expectEmit(true, true, false, false);
    //     emit WMNftPoolMintAndBurn.MessageSent(
    //         messageId, destinationChainSelector, USER, abi.encode(0, USER), address(sourceLinkToken), fees
    //     );
    //     wmNftPool.burnAndSendNft(0, USER, destinationChainSelector, USER, IERC20(address(sourceLinkToken)));
    //     vm.stopPrank();
    // }

    function testInvalidReceiverAddressFork() public addDestChain prepareToUser {
        vm.expectRevert(WMNftPoolMintAndBurn.WMNftPoolMintAndBurn__InvalidReceiverAddress.selector);
        vm.startPrank(USER);
        wmNftPool.burnAndSendNft(0, USER, destinationChainSelector, address(0), IERC20(address(sourceLinkToken)));
        vm.stopPrank();
    }

    function testUnAllowedDestChainFork() public prepareToUser {
        vm.expectRevert(
            abi.encodeWithSelector(
                WMNftPoolMintAndBurn.WMNftPoolMintAndBurn__DestinationChainNotAllowlisted.selector,
                destinationChainSelector
            )
        );
        vm.startPrank(USER);
        wmNftPool.burnAndSendNft(0, USER, destinationChainSelector, USER, IERC20(address(sourceLinkToken)));
        vm.stopPrank();
    }

    //////////////////////////////////////////
    /////////// Test WithdrawToken  //////////
    //////////////////////////////////////////

    function testCanRevertNotingToWithdrawFork() public addDestChain {
        vm.startPrank(wmNftPool.owner());
        vm.expectRevert(WMNftPoolMintAndBurn.WMNftPoolMintAndBurn__NothingToWithdraw.selector);
        wmNftPool.withdrawToken(USER, address(sourceLinkToken));
        vm.stopPrank();
    }

    function testWithdrawTokenFork() public addDestChain prepareToUser {
        vm.startPrank(wmNftPool.owner());
        wmNftPool.withdrawToken(USER, address(sourceLinkToken));
        vm.stopPrank();
        assert(sourceLinkToken.balanceOf(wmNftPool.owner()) == 0);
        assert(sourceLinkToken.balanceOf(USER) > 0);
    }

    //////////////////////////////////////////
    /////// Test ccipReceive        //////////
    //////////////////////////////////////////

    modifier prepareForReceive() {
        vm.selectFork(sourceFork);
        vm.startPrank(wmNftPool.owner());
        wmNftPool.allowlistSourceChain(destinationChainSelector, true);
        wmNftPool.allowlistSender(USER, true);
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
        // vm.prank(wmNftPool.getRouter());  // this is the wmNftPool router, if prank, it not revert.
        vm.prank(USER);
        vm.expectRevert();
        wmNftPool.ccipReceive(any2EvmMessage);
    }

    function testCanRevertIfNotAllowedSourceChainFork() public {
        Client.EVMTokenAmount[] memory tokensToSendDetails = prepareScenario();

        Client.Any2EVMMessage memory any2EvmMessage = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: destinationChainSelector,
            sender: abi.encode(USER),
            data: abi.encode(0, USER),
            destTokenAmounts: tokensToSendDetails
        });

        vm.selectFork(sourceFork);
        vm.startPrank(wmNftPool.owner());
        wmNftPool.allowlistSender(USER, true);
        vm.stopPrank();

        vm.prank(wmNftPool.getRouter());
        vm.expectRevert(
            abi.encodeWithSelector(
                WMNftPoolMintAndBurn.WMNftPoolMintAndBurn__SourceChainNotAllowed.selector, destinationChainSelector
            )
        );
        wmNftPool.ccipReceive(any2EvmMessage);
    }

    function testCanRevertIfNotAllowedSenderFork() public {
        Client.EVMTokenAmount[] memory tokensToSendDetails = prepareScenario();

        Client.Any2EVMMessage memory any2EvmMessage = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: destinationChainSelector,
            sender: abi.encode(USER),
            data: abi.encode(0, USER),
            destTokenAmounts: tokensToSendDetails
        });
        vm.selectFork(sourceFork);
        vm.startPrank(wmNftPool.owner());
        wmNftPool.allowlistSourceChain(destinationChainSelector, true);
        wmNftPool.allowlistSender(USER, false);
        vm.stopPrank();

        vm.prank(wmNftPool.getRouter());
        vm.expectRevert(
            abi.encodeWithSelector(WMNftPoolMintAndBurn.WMNftPoolMintAndBurn__SenderNotAllowed.selector, USER)
        );
        wmNftPool.ccipReceive(any2EvmMessage);
    }

    function testCCIPReceiveFork() public prepareForReceive {
        Client.EVMTokenAmount[] memory tokensToSendDetails = prepareScenario();

        Client.Any2EVMMessage memory any2EvmMessage = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: destinationChainSelector,
            sender: abi.encode(USER),
            data: abi.encode(0, USER),
            destTokenAmounts: tokensToSendDetails
        });

        vm.startPrank(wmNftPool.getRouter());
        vm.expectEmit(true, true, false, false);
        emit WMNftPoolMintAndBurn.NftMinted(USER, 0);

        wmNftPool.ccipReceive(any2EvmMessage);
        vm.stopPrank();
        assert(wmoodNft.balanceOf(USER) == 1);
        assert(wmoodNft.ownerOf(0) == USER);
    }
}
