//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {WMoodNft} from "src/WMoodNft.sol";
import {DeployWrappedMNftPool} from "script/deploy/DeployWrappedMNftPool.s.sol";
import {WMNftPoolMintAndBurn} from "src/WMNftPoolMintAndBurn.sol";
import {CCIPLocalSimulator, IRouterClient, LinkToken} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

// import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MNftPoolTest is Test {
    CCIPLocalSimulator public ccipLocalSimulator;
    DeployWrappedMNftPool public deployWrappedMNftPool;
    WMNftPoolMintAndBurn public wmNftPool;
    WMoodNft public wmoodNft;

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

        deployWrappedMNftPool = new DeployWrappedMNftPool();
        (wmNftPool, wmoodNft) = deployWrappedMNftPool.run();

        ccipLocalSimulator.requestLinkFromFaucet(USER, 1 ether);
        vm.deal(USER, 5 ether);
    }

    modifier addDestChain() {
        vm.startPrank(wmNftPool.owner());
        wmNftPool.allowlistDestinationChain(chainSelector, true);
        vm.stopPrank();
        _;
    }

    modifier prepareToUser() {
        vm.startPrank(USER);
        linkToken.transfer(address(wmNftPool), 1 ether);
        // (bool success,) = address(mNftPoolLockAndRelease).call{value: 1 ether}("");
        payable(address(wmNftPool)).transfer(1 ether);
        wmoodNft.mintNft();
        wmoodNft.approve(address(wmNftPool), 0);
        // moodNft.approve(USER, 0);
        vm.stopPrank();
        _;
    }

    //////////////////////////////////////////
    /////////// Test burnAndSendNft //////////
    //////////////////////////////////////////

    function testBurnAndSendNft() public addDestChain prepareToUser {
        assert(wmoodNft.balanceOf(USER) == 1);
        assert(wmoodNft.ownerOf(0) == USER);
        vm.startPrank(USER);
        wmNftPool.burnAndSendNft(0, USER, chainSelector, USER, IERC20(address(linkToken)));
        vm.stopPrank();
        assert(wmoodNft.balanceOf(USER) == 0);
        assert(wmoodNft.balanceOf(address(wmNftPool)) == 0);
        // vm.expectRevert(abi.encodeWithSelector(ERC721.ERC721NonexistentToken.selector, 0));
        vm.expectRevert();
        assert(wmoodNft.ownerOf(0) == address(0));
    }

    function testCanEmitNftBurned() public addDestChain prepareToUser {
        vm.startPrank(USER);
        vm.expectEmit(true, false, false, false);
        emit WMNftPoolMintAndBurn.NftBurned(0);
        wmNftPool.burnAndSendNft(0, USER, chainSelector, USER, IERC20(address(linkToken)));
        vm.stopPrank();
    }

    function testCanEmitMessageSent() public addDestChain prepareToUser {
        vm.startPrank(address(wmNftPool));
        Client.EVM2AnyMessage memory evm2AnyMessage =
            wmNftPool.buildCCIPMessage(USER, abi.encode(0, USER), address(linkToken));

        IRouterClient router = IRouterClient(wmNftPool.getRouter());

        uint256 fees = router.getFee(chainSelector, evm2AnyMessage);
        linkToken.approve(address(router), fees);
        bytes32 messageId = router.ccipSend(chainSelector, evm2AnyMessage);

        vm.stopPrank();

        vm.startPrank(USER);
        vm.expectEmit(true, true, false, false);
        emit WMNftPoolMintAndBurn.MessageSent(
            messageId, chainSelector, USER, abi.encode(0, USER), address(linkToken), fees
        );
        wmNftPool.burnAndSendNft(0, USER, chainSelector, USER, IERC20(address(linkToken)));
        vm.stopPrank();
    }

    // /**
    //  *  @? Why the link fees is 0?
    //  */
    // function testCanRevertNotEnoughtBalance() public addDestChain prepareToUser {
    //     vm.startPrank(address(wmNftPool));
    //     linkToken.transfer(USER, 1 ether);
    //     console.log("Pool Link Balance", linkToken.balanceOf(address(wmNftPool)));
    //     vm.stopPrank();

    //     Client.EVM2AnyMessage memory evm2AnyMessage =
    //         wmNftPool.buildCCIPMessage(USER, abi.encode(0, USER), address(linkToken));

    //     IRouterClient router = IRouterClient(wmNftPool.getRouter());

    //     uint256 fees = router.getFee(chainSelector, evm2AnyMessage);
    //     console.log("Fees", fees);
    //     // 0 = 0
    //     vm.startPrank(USER);
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             WMNftPoolMintAndBurn.WMNftPoolMintAndBurn__NotEnoughBalance.selector,
    //             linkToken.balanceOf(address(wmNftPool)),
    //             fees
    //         )
    //     );
    //     wmNftPool.burnAndSendNft(0, USER, chainSelector, USER, IERC20(address(linkToken)));
    //     vm.stopPrank();
    // }

    function testInvalidReceiverAddress() public addDestChain prepareToUser {
        vm.expectRevert(WMNftPoolMintAndBurn.WMNftPoolMintAndBurn__InvalidReceiverAddress.selector);
        vm.startPrank(USER);
        wmNftPool.burnAndSendNft(0, USER, chainSelector, address(0), IERC20(address(linkToken)));
        vm.stopPrank();
    }

    function testUnAllowedDestChain() public prepareToUser {
        vm.expectRevert(
            abi.encodeWithSelector(
                WMNftPoolMintAndBurn.WMNftPoolMintAndBurn__DestinationChainNotAllowlisted.selector, chainSelector
            )
        );
        vm.startPrank(USER);
        wmNftPool.burnAndSendNft(0, USER, chainSelector, USER, IERC20(address(linkToken)));
        vm.stopPrank();
    }

    //////////////////////////////////////////
    /////////// Test WithdrawToken  //////////
    //////////////////////////////////////////

    function testCanRevertNotingToWithdraw() public addDestChain {
        vm.startPrank(wmNftPool.owner());
        vm.expectRevert(WMNftPoolMintAndBurn.WMNftPoolMintAndBurn__NothingToWithdraw.selector);
        wmNftPool.withdrawToken(USER, address(linkToken));
        vm.stopPrank();
    }

    function testWithdrawToken() public addDestChain prepareToUser {
        assert(linkToken.balanceOf(USER) == 0);
        vm.startPrank(wmNftPool.owner());
        wmNftPool.withdrawToken(USER, address(linkToken));
        vm.stopPrank();
        assert(linkToken.balanceOf(wmNftPool.owner()) == 0);
        assert(linkToken.balanceOf(USER) > 0);
    }

    //////////////////////////////////////////
    /////////// Test AllowDestChain  //////////
    //////////////////////////////////////////

    function testNotOwnerCanNotAllowDestChain() public {
        vm.expectRevert("Only callable by owner");
        vm.startPrank(USER);
        wmNftPool.allowlistDestinationChain(chainSelector, true);
        vm.stopPrank();
    }

    function testAllowDestChain() public {
        vm.startPrank(wmNftPool.owner());
        wmNftPool.allowlistDestinationChain(chainSelector, true);
        vm.stopPrank();
        assert(wmNftPool.allowlistedDestinationChains(chainSelector));
    }

    //////////////////////////////////////////
    /////// Test AllowSourceChain  //////////
    //////////////////////////////////////////
    function testNotOwnerCanNotAllowSourceChain() public {
        vm.expectRevert("Only callable by owner");
        vm.startPrank(USER);
        wmNftPool.allowlistSourceChain(chainSelector, true);
        vm.stopPrank();
    }

    function testAllowSourceChain() public {
        vm.startPrank(wmNftPool.owner());
        wmNftPool.allowlistSourceChain(chainSelector, true);
        vm.stopPrank();
        assert(wmNftPool.allowlistedSourceChains(chainSelector));
    }
    //////////////////////////////////////////
    /////// Test Allow Senders      //////////
    //////////////////////////////////////////

    function testNotOwnerCanNotAllowSender() public {
        vm.expectRevert("Only callable by owner");
        vm.startPrank(USER);
        wmNftPool.allowlistSender(USER, true);
        vm.stopPrank();
    }

    function testAllowSender() public {
        vm.startPrank(wmNftPool.owner());
        wmNftPool.allowlistSender(USER, true);
        vm.stopPrank();
        assert(wmNftPool.allowlistedSenders(USER));
    }
    //////////////////////////////////////////
    /////// Test ccipReceive        //////////
    //////////////////////////////////////////

    modifier prepareForReceive() {
        vm.startPrank(wmNftPool.owner());
        wmNftPool.allowlistSourceChain(chainSelector, true);
        wmNftPool.allowlistSender(USER, true);
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
        // vm.prank(wmNftPool.getRouter());  // this is the wmNftPool router, if prank, it not revert.
        vm.prank(USER);
        vm.expectRevert();
        wmNftPool.ccipReceive(any2EvmMessage);
    }

    function testCanRevertIfNotAllowedSourceChain() public {
        vm.startPrank(wmNftPool.owner());
        wmNftPool.allowlistSender(USER, true);
        vm.stopPrank();
        Client.EVMTokenAmount[] memory tokensToSendDetails = prepareScenario();

        Client.Any2EVMMessage memory any2EvmMessage = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: chainSelector,
            sender: abi.encode(USER),
            data: abi.encode(0, USER),
            destTokenAmounts: tokensToSendDetails
        });

        vm.prank(wmNftPool.getRouter());
        vm.expectRevert(
            abi.encodeWithSelector(
                WMNftPoolMintAndBurn.WMNftPoolMintAndBurn__SourceChainNotAllowed.selector, chainSelector
            )
        );
        wmNftPool.ccipReceive(any2EvmMessage);
    }

    function testCanRevertIfNotAllowedSender() public {
        vm.startPrank(wmNftPool.owner());
        wmNftPool.allowlistSourceChain(chainSelector, true);
        wmNftPool.allowlistSender(USER, false);
        vm.stopPrank();
        Client.EVMTokenAmount[] memory tokensToSendDetails = prepareScenario();

        Client.Any2EVMMessage memory any2EvmMessage = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: chainSelector,
            sender: abi.encode(USER),
            data: abi.encode(0, USER),
            destTokenAmounts: tokensToSendDetails
        });

        vm.prank(wmNftPool.getRouter());
        vm.expectRevert(
            abi.encodeWithSelector(WMNftPoolMintAndBurn.WMNftPoolMintAndBurn__SenderNotAllowed.selector, USER)
        );
        wmNftPool.ccipReceive(any2EvmMessage);
    }

    function testCCIPReceive() public prepareForReceive {
        Client.EVMTokenAmount[] memory tokensToSendDetails = prepareScenario();

        Client.Any2EVMMessage memory any2EvmMessage = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: chainSelector,
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
