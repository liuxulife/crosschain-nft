//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract HelpConfigTest is Test {
    HelperConfig helperConfig;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ARB_SEPOLIA_CHAIN_ID = 421614;

    address public constant SEPOLIA_ROUTER = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
    address public constant SEPOLIA_LINK = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    address public constant ARB_SEPOLIA_ROUTER = 0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165;
    address public constant ARB_SEPOLIA_LINK = 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E;

    function setUp() public {
        helperConfig = new HelperConfig();
    }
    //////////////////////////////////////////
    /////// Test Helper config     //////////
    //////////////////////////////////////////

    function testCanRevertChainIdNotSupported() public {
        vm.chainId(999);
        vm.expectRevert(HelperConfig.HelperConfig__ChainIdNotSupported.selector);
        // console.log(block.chainid);
        helperConfig.getConfig();
    }

    function testIfLocalChain() public {
        console.log(block.chainid);
        HelperConfig.NetWorkConfig memory netWorkConfig = helperConfig.getConfig();

        assert(netWorkConfig.router == address(helperConfig.sourceChainRouter()));
        assert(netWorkConfig.link == address(helperConfig.linkToken()));
    }

    function testIfSepoliaChain() public {
        vm.chainId(ETH_SEPOLIA_CHAIN_ID);
        HelperConfig.NetWorkConfig memory netWorkConfig = helperConfig.getConfig();

        assert(netWorkConfig.router == SEPOLIA_ROUTER);
        assert(netWorkConfig.link == SEPOLIA_LINK);
    }

    function testIfArbSepoliaChain() public {
        vm.chainId(ARB_SEPOLIA_CHAIN_ID);
        HelperConfig.NetWorkConfig memory netWorkConfig = helperConfig.getConfig();

        assert(netWorkConfig.router == ARB_SEPOLIA_ROUTER);
        assert(netWorkConfig.link == ARB_SEPOLIA_LINK);
    }
}
