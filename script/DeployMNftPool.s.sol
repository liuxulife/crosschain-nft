//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MNftPoolLockAndRelease} from "src/MNftPoolLockAndRelease.sol";
import {DeployMoodNft} from "script/DeployMoodNft.s.sol";
import {MoodNft} from "src/MoodNft.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployMNftPool is Script {
    HelperConfig public helperConfig = new HelperConfig();
    HelperConfig.NetWorkConfig netWorkConfig = helperConfig.getConfig();

    DeployMoodNft deployMoodNft;
    MoodNft public moodNft;

    address public router = netWorkConfig.router;
    address public link = netWorkConfig.link;

    function run() external returns (MNftPoolLockAndRelease) {
        // vm.startBroadcast();
        deployMoodNft = new DeployMoodNft();
        moodNft = deployMoodNft.run();

        MNftPoolLockAndRelease moodNftPool = new MNftPoolLockAndRelease(router, link, address(moodNft));

        // vm.stopBroadcast();
        return moodNftPool;
    }
}
