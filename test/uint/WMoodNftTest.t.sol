//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {WMoodNft} from "src/WMoodNft.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {DeployWMoodNft} from "script/DeployWMoodNft.s.sol";

contract WMoodNftTest is Test {
    WMoodNft public wmoodNft;
    DeployWMoodNft public deployWMoodNft;

    address public USER = makeAddr("USER");

    string sadSvg = vm.readFile("./images/sad.svg");
    string public constant SAD_SVG_IMAGE_URI =
        "data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBzdGFuZGFsb25lPSJubyI/Pgo8c3ZnIHdpZHRoPSIxMDI0cHgiIGhlaWdodD0iMTAyNHB4IiB2aWV3Qm94PSIwIDAgMTAyNCAxMDI0IiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPgogIDxwYXRoIGZpbGw9IiMzMzMiIGQ9Ik01MTIgNjRDMjY0LjYgNjQgNjQgMjY0LjYgNjQgNTEyczIwMC42IDQ0OCA0NDggNDQ4IDQ0OC0yMDAuNiA0NDgtNDQ4Uzc1OS40IDY0IDUxMiA2NHptMCA4MjBjLTIwNS40IDAtMzcyLTE2Ni42LTM3Mi0zNzJzMTY2LjYtMzcyIDM3Mi0zNzIgMzcyIDE2Ni42IDM3MiAzNzItMTY2LjYgMzcyLTM3MiAzNzJ6Ii8+CiAgPHBhdGggZmlsbD0iI0U2RTZFNiIgZD0iTTUxMiAxNDBjLTIwNS40IDAtMzcyIDE2Ni42LTM3MiAzNzJzMTY2LjYgMzcyIDM3MiAzNzIgMzcyLTE2Ni42IDM3Mi0zNzItMTY2LjYtMzcyLTM3Mi0zNzJ6TTI4OCA0MjFhNDguMDEgNDguMDEgMCAwIDEgOTYgMCA0OC4wMSA0OC4wMSAwIDAgMS05NiAwem0zNzYgMjcyaC00OC4xYy00LjIgMC03LjgtMy4yLTguMS03LjRDNjA0IDYzNi4xIDU2Mi41IDU5NyA1MTIgNTk3cy05Mi4xIDM5LjEtOTUuOCA4OC42Yy0uMyA0LjItMy45IDcuNC04LjEgNy40SDM2MGE4IDggMCAwIDEtOC04LjRjNC40LTg0LjMgNzQuNS0xNTEuNiAxNjAtMTUxLjZzMTU1LjYgNjcuMyAxNjAgMTUxLjZhOCA4IDAgMCAxLTggOC40em0yNC0yMjRhNDguMDEgNDguMDEgMCAwIDEgMC05NiA0OC4wMSA0OC4wMSAwIDAgMSAwIDk2eiIvPgogIDxwYXRoIGZpbGw9IiMzMzMiIGQ9Ik0yODggNDIxYTQ4IDQ4IDAgMSAwIDk2IDAgNDggNDggMCAxIDAtOTYgMHptMjI0IDExMmMtODUuNSAwLTE1NS42IDY3LjMtMTYwIDE1MS42YTggOCAwIDAgMCA4IDguNGg0OC4xYzQuMiAwIDcuOC0zLjIgOC4xLTcuNCAzLjctNDkuNSA0NS4zLTg4LjYgOTUuOC04OC42czkyIDM5LjEgOTUuOCA4OC42Yy4zIDQuMiAzLjkgNy40IDguMSA3LjRINjY0YTggOCAwIDAgMCA4LTguNEM2NjcuNiA2MDAuMyA1OTcuNSA1MzMgNTEyIDUzM3ptMTI4LTExMmE0OCA0OCAwIDEgMCA5NiAwIDQ4IDQ4IDAgMSAwLTk2IDB6Ii8+Cjwvc3ZnPg==";

    function setUp() public {
        deployWMoodNft = new DeployWMoodNft();
        wmoodNft = deployWMoodNft.run();
    }

    modifier UserMint() {
        vm.prank(USER);
        wmoodNft.mintNft();
        _;
    }

    function testNameAndSymbolIsCorrect() public view {
        string memory expectedName = "Wrapped Mood NFT";
        string memory actualName = wmoodNft.name();
        string memory expectedSymbol = "WMN";

        assert(keccak256(abi.encodePacked(expectedName)) == keccak256(abi.encodePacked(actualName)));
        assert(keccak256(abi.encodePacked(wmoodNft.symbol())) == keccak256(abi.encodePacked(expectedSymbol)));
    }

    function testCanMintAndHaveBalance() public UserMint {
        assert(wmoodNft.balanceOf(USER) == 1);
        assert(wmoodNft.ownerOf(0) == USER);
    }

    function testCanMintWithSpecificTokenId() public {
        uint256 tokenId = 1;
        wmoodNft.mintWithSpecificTokenId(USER, tokenId);

        assert(wmoodNft.balanceOf(USER) == 1);
        assert(wmoodNft.ownerOf(tokenId) == USER);
    }

    function testCanNotMintIfTokenIdAlreadyMinted() public UserMint {
        vm.prank(USER);
        vm.expectRevert();
        wmoodNft.mintWithSpecificTokenId(USER, 0);
    }

    function testCantMintIfTokenIdMinted() public {
        vm.startPrank(USER);
        wmoodNft.mintWithSpecificTokenId(USER, 0);
        wmoodNft.mintNft();
        wmoodNft.mintWithSpecificTokenId(USER, 4);
        wmoodNft.mintNft();
        vm.expectRevert();
        wmoodNft.mintNft();
    }

    function testSVGToImageUri() public view {
        string memory changedUri = deployWMoodNft.svgToImageURI(sadSvg);
        assertEq(changedUri, SAD_SVG_IMAGE_URI);
    }
}
