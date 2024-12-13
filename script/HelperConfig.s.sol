//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {CCIPLocalSimulator, IRouterClient, LinkToken} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";

contract HelperConfig is Script {
    error HelperConfig__ChainIdNotSupported();

    struct NetWorkConfig {
        address router;
        address link;
    }

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ARB_SEPOLIA_CHAIN_ID = 421614;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    address public constant SEPOLIA_ROUTER = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
    address public constant SEPOLIA_LINK = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    address public constant ARB_SEPOLIA_ROUTER = 0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165;
    address public constant ARB_SEPOLIA_LINK = 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E;

    CCIPLocalSimulator ccipLocalSimulator;
    IRouterClient public sourceChainRouter;
    LinkToken public linkToken;

    // mapping(uint256 chainId => NetWorkConfig) public networkConfigs;

    function getConfig() public returns (NetWorkConfig memory) {
        return getNetWorkConfig(block.chainid);
    }

    function getNetWorkConfig(uint256 chainId) public returns (NetWorkConfig memory) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID) {
            return getSepoliaConfig();
        } else if (chainId == ARB_SEPOLIA_CHAIN_ID) {
            return getArbSepoliaConfig();
        } else if (chainId == LOCAL_CHAIN_ID) {
            // return getOrCreateAnvilConfig();
            return getSimulatorConfig();
        } else {
            // return getSimulatorConfig();
            revert HelperConfig__ChainIdNotSupported();
        }
    }

    function getSimulatorConfig() public returns (NetWorkConfig memory) {
        ccipLocalSimulator = new CCIPLocalSimulator();
        (, IRouterClient _sourceChainRouter,,, LinkToken _linkToken,,) = ccipLocalSimulator.configuration();

        sourceChainRouter = _sourceChainRouter;
        linkToken = _linkToken;
        return NetWorkConfig({router: address(sourceChainRouter), link: address(linkToken)});
    }

    function getSepoliaConfig() public pure returns (NetWorkConfig memory) {
        return NetWorkConfig({router: SEPOLIA_ROUTER, link: SEPOLIA_LINK});
    }

    function getArbSepoliaConfig() public pure returns (NetWorkConfig memory) {
        return NetWorkConfig({router: ARB_SEPOLIA_ROUTER, link: ARB_SEPOLIA_LINK});
    }

    // function getOrCreateAnvilConfig() public pure returns (NetWorkConfig memory) {
    //     return NetWorkConfig({router: address(0), link: address(0)});
    // }
}
