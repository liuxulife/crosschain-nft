//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {MoodNft} from "src/MoodNft.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract MoodNftTest is Test {
    MoodNft moodNft;
    address USER = makeAddr("user");
    address OTHER = makeAddr("other");

    string public constant HAPPY_SVG_URI =
        "data:image/svg+xml;base64,PHN2ZyB2aWV3Qm94PSIwIDAgMjAwIDIwMCIgd2lkdGg9IjQwMCIgIGhlaWdodD0iNDAwIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPgogIDxjaXJjbGUgY3g9IjEwMCIgY3k9IjEwMCIgZmlsbD0ieWVsbG93IiByPSI3OCIgc3Ryb2tlPSJibGFjayIgc3Ryb2tlLXdpZHRoPSIzIi8+CiAgPGcgY2xhc3M9ImV5ZXMiPgogICAgPGNpcmNsZSBjeD0iNzAiIGN5PSI4MiIgcj0iMTIiLz4KICAgIDxjaXJjbGUgY3g9IjEyNyIgY3k9IjgyIiByPSIxMiIvPgogIDwvZz4KICA8cGF0aCBkPSJtMTM2LjgxIDExNi41M2MuNjkgMjYuMTctNjQuMTEgNDItODEuNTItLjczIiBzdHlsZT0iZmlsbDpub25lOyBzdHJva2U6IGJsYWNrOyBzdHJva2Utd2lkdGg6IDM7Ii8+Cjwvc3ZnPg==";
    string public constant SAD_SVG_URI =
        "data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBzdGFuZGFsb25lPSJubyIPgo8c3ZnIHdpZHRoPSIxMDI0cHgiIGhlaWdodD0iMTAyNHB4IiB2aWV3Qm94PSIwIDAgMTAyNCAxMDI0IiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPgogIDxwYXRoIGZpbGw9IiMzMzMiIGQ9Ik01MTIgNjRDMjY0LjYgNjQgNjQgMjY0LjYgNjQgNTEyczIwMC42IDQ0OCA0NDggNDQ4IDQ0OC0yMDAuNiA0NDgtNDQ4Uzc1OS40IDY0IDUxMiA2NHptMCA4MjBjLTIwNS40IDAtMzcyLTE2Ni42LTM3Mi0zNzJzMTY2LjYtMzcyIDM3Mi0zNzIgMzcyIDE2Ni42IDM3MiAzNzItMTY2LjYgMzcyLTM3MiAzNzJ6Ii8+CiAgPHBhdGggZmlsbD0iI0U2RTZFNiIgZD0iTTUxMiAxNDBjLTIwNS40IDAtMzcyIDE2Ni42LTM3MiAzNzJzMTY2LjYgMzcyIDM3MiAzNzIgMzcyLTE2Ni42IDM3Mi0zNzItMTY2LjYtMzcyLTM3Mi0zNzJ6TTI4OCA0MjFhNDguMDEgNDguMDEgMCAwIDEgOTYgMCA0OC4wMSA0OC4wMSAwIDAgMS05NiAwem0zNzYgMjcyaC00OC4xYy00LjIgMC03LjgtMy4yLTguMS03LjRDNjA0IDYzNi4xIDU2Mi41IDU5NyA1MTIgNTk3cy05Mi4xIDM5LjEtOTUuOCA4OC42Yy0uMyA0LjItMy45IDcuNC04LjEgNy40SDM2MGE4IDggMCAwIDEtOC04LjRjNC40LTg0LjMgNzQuNS0xNTEuNiAxNjAtMTUxLjZzMTU1LjYgNjcuMyAxNjAgMTUxLjZhOCA4IDAgMCAxLTggOC40em0yNC0yMjRhNDguMDEgNDguMDEgMCAwIDEgMC05NiA0OC4wMSA0OC4wMSAwIDAgMSAwIDk2eiIvPgogIDxwYXRoIGZpbGw9IiMzMzMiIGQ9Ik0yODggNDIxYTQ4IDQ4IDAgMSAwIDk2IDAgNDggNDggMCAxIDAtOTYgMHptMjI0IDExMmMtODUuNSAwLTE1NS42IDY3LjMtMTYwIDE1MS42YTggOCAwIDAgMCA4IDguNGg0OC4xYzQuMiAwIDcuOC0zLjIgOC4xLTcuNCAzLjctNDkuNSA0NS4zLTg4LjYgOTUuOC04OC42czkyIDM5LjEgOTUuOCA4OC42Yy4zIDQuMiAzLjkgNy40IDguMSA3LjRINjY0YTggOCAwIDAgMCA4LTguNEM2NjcuNiA2MDAuMyA1OTcuNSA1MzMgNTEyIDUzM3ptMTI4LTExMmE0OCA0OCAwIDEgMCA5NiAwIDQ4IDQ4IDAgMSAwLTk2IDB6Ii8+Cjwvc3ZnPg==";

    function setUp() public {
        moodNft = new MoodNft(HAPPY_SVG_URI, SAD_SVG_URI);
    }

    modifier UserMint() {
        vm.prank(USER);
        moodNft.mintNft();
        _;
    }

    function testNameAndSymbolAreCorrect() public view {
        string memory expectedName = "Mood NFT";
        string memory actualName = moodNft.name();
        string memory expectedSymbol = "MN";

        assert(keccak256(abi.encodePacked(expectedName)) == keccak256(abi.encodePacked(actualName)));
        assert(keccak256(abi.encodePacked(moodNft.symbol())) == keccak256(abi.encodePacked((expectedSymbol))));
    }

    function testInitialCounter() public view {
        assert(moodNft.getTokenCounter() == 0);
    }

    function testInitialURI() public view {
        string memory processHappyURI = HAPPY_SVG_URI;
        string memory processSadURI = SAD_SVG_URI;
        assert(
            keccak256(abi.encodePacked(moodNft.getHappySvgImageUri())) == keccak256(abi.encodePacked(processHappyURI))
        );
        assert(keccak256(abi.encodePacked(moodNft.getSadSvgImageUri())) == keccak256(abi.encodePacked(processSadURI)));
    }

    function testCanMintAndHaveBalance() public UserMint {
        assert(moodNft.balanceOf(USER) == 1);
        assert(moodNft.ownerOf(0) == USER);
    }

    function testMultipleUsersCanMint() public {
        vm.prank(USER);
        moodNft.mintNft();
        assert(moodNft.getTokenCounter() == 1);
        vm.prank(OTHER);
        moodNft.mintNft();
        assert(moodNft.getTokenCounter() == 2);

        assert(moodNft.s_tokenIdToMood(0) == MoodNft.Mood.HAPPY);
        assert(moodNft.s_tokenIdToMood(1) == MoodNft.Mood.HAPPY);
        assert(moodNft.balanceOf(USER) == 1);
        assert(moodNft.balanceOf(OTHER) == 1);
        assert(moodNft.ownerOf(0) == USER);
        assert(moodNft.ownerOf(1) == OTHER);
    }

    function testCanRevertCannotFlipMoodNotOwner() public UserMint {
        vm.startPrank(OTHER);
        vm.expectRevert(MoodNft.MoodNft__CannotFlipMoodNotOwner.selector);
        moodNft.flipMood(0);
    }

    function testFlipMoodForInvalidTokenId() public {
        vm.startPrank(USER);
        vm.expectRevert();
        moodNft.flipMood(999); // Token ID that doesn't exist
    }

    // What we need to do is that we should cover the branches of the if function
    function testCanFlipMood() public UserMint {
        string memory processHappyURI = HAPPY_SVG_URI;
        string memory processSadURI = SAD_SVG_URI;

        assert(moodNft.getTokenCounter() > 0);
        assert(
            keccak256(abi.encodePacked(moodNft.tokenURI(0)))
                == keccak256(abi.encodePacked(ProcessTheURI(processHappyURI)))
        );
        assert(moodNft.s_tokenIdToMood(0) == MoodNft.Mood.HAPPY);

        vm.prank(USER);
        moodNft.flipMood(0);

        assert(moodNft.s_tokenIdToMood(0) == MoodNft.Mood.SAD);
        assert(
            keccak256(abi.encodePacked(moodNft.tokenURI(0)))
                == keccak256(abi.encodePacked(ProcessTheURI(processSadURI)))
        );

        vm.prank(USER);
        moodNft.flipMood(0);
        assert(moodNft.s_tokenIdToMood(0) == MoodNft.Mood.HAPPY);
        assert(
            keccak256(abi.encodePacked(moodNft.tokenURI(0)))
                == keccak256(abi.encodePacked(ProcessTheURI(processHappyURI)))
        );
    }

    function testCanGetTokenURI() public UserMint {
        string memory processHappyURI = HAPPY_SVG_URI;
        string memory processSadURI = SAD_SVG_URI;
        assert(
            keccak256(abi.encodePacked(moodNft.tokenURI(0)))
                == keccak256(abi.encodePacked(ProcessTheURI(processHappyURI)))
        );

        vm.prank(USER);
        moodNft.flipMood(0);
        assert(
            keccak256(abi.encodePacked(moodNft.tokenURI(0)))
                == keccak256(abi.encodePacked(ProcessTheURI(processSadURI)))
        );
    }

    function ProcessTheURI(string memory imageURI) public view returns (string memory) {
        return string(
            abi.encodePacked(
                moodNft.getBaseURI(),
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name": "',
                            moodNft.name(),
                            '", "description": "An NFT that reflects the owner mood.","attributes": [{"trait_type": "moodiness", "value": 100}], "image": "',
                            imageURI,
                            '"}'
                        )
                    )
                )
            )
        );
    }

    function testCanGetHappyTokenURI() public view {
        string memory expectedHappyURI = HAPPY_SVG_URI;
        assert(
            keccak256(abi.encodePacked(moodNft.getHappySvgImageUri())) == keccak256(abi.encodePacked(expectedHappyURI))
        );
    }

    function testCanGetSadTokenURI() public view {
        string memory expectedSadURI = SAD_SVG_URI;
        assert(keccak256(abi.encodePacked(moodNft.getSadSvgImageUri())) == keccak256(abi.encodePacked(expectedSadURI)));
    }

    function testCanGetTokenCounter() public {
        uint256 startTokenCounter = moodNft.getTokenCounter();
        console.log(startTokenCounter);
        vm.prank(USER);
        moodNft.mintNft();
        uint256 endTokenCounter = moodNft.getTokenCounter();
        console.log(endTokenCounter);
        assert(startTokenCounter + 1 == endTokenCounter);
    }

    function testCanGetBaseUri() public view {
        string memory expectedBaseURI = "data:application/json;base64,";
        assert(keccak256(abi.encodePacked(moodNft.getBaseURI())) == keccak256(abi.encodePacked(expectedBaseURI)));
    }
}
