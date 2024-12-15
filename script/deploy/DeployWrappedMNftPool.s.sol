//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {WMNftPoolMintAndBurn} from "src/WMNftPoolMintAndBurn.sol";
import {DeployWMoodNft} from "script/deploy/DeployWMoodNft.s.sol";
import {WMoodNft} from "src/WMoodNft.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployWrappedMNftPool is Script {
    HelperConfig helperConfig = new HelperConfig();
    HelperConfig.NetWorkConfig netWorkConfig = helperConfig.getConfig();

    DeployWMoodNft deployWMoodNft;
    WMoodNft public wmoodNft;

    address public router = netWorkConfig.router;
    address public link = netWorkConfig.link;

    function run() external returns (WMNftPoolMintAndBurn, WMoodNft) {
        deployWMoodNft = new DeployWMoodNft();
        wmoodNft = deployWMoodNft.run();

        WMNftPoolMintAndBurn wmoodNftPool = new WMNftPoolMintAndBurn(router, link, address(wmoodNft));

        return (wmoodNftPool, wmoodNft);
    }
}
