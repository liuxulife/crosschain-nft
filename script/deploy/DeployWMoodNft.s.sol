//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {WMoodNft} from "src/WMoodNft.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract DeployWMoodNft is Script {
    function run() external returns (WMoodNft) {
        string memory sadSvg = vm.readFile("./images/sad.svg");
        string memory happySvg = vm.readFile("./images/happy.svg");

        vm.startBroadcast();
        WMoodNft wmoodNft = new WMoodNft(svgToImageURI(happySvg), svgToImageURI(sadSvg), "Wrapped Mood NFT", "WMN");
        vm.stopBroadcast();
        return wmoodNft;
    }

    function svgToImageURI(string memory svg) public pure returns (string memory) {
        string memory baseURL = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(svg))));

        return string(abi.encodePacked(baseURL, svgBase64Encoded));
    }
}
