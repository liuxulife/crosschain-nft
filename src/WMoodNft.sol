// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MoodNft} from "src/MoodNft.sol";

contract WMoodNft is MoodNft {
    constructor(string memory happySvgImageUri, string memory sadSvgImageUri, string memory name, string memory symbol)
        MoodNft(happySvgImageUri, sadSvgImageUri, name, symbol)
    {}

    //////////////////////////////////////////
    /////////// public functions /////////////
    //////////////////////////////////////////

    /**
     * @notice mint NFT
     * @dev tokenId must not exist
     */
    function mintNft() public override {
        //     require(
        //         s_tokenIdToMood[s_tokenCounter] == Mood.HAPPY || s_tokenIdToMood[s_tokenCounter] == Mood.SAD,
        //         "TokenId already minted"
        //     );
        _safeMint(msg.sender, s_tokenCounter);
        s_tokenIdToMood[s_tokenCounter] = Mood.HAPPY;
        s_tokenCounter++;
    }

    /**
     * @param to mint NFT to
     * @param _tokenId specific tokenId to mint
     * @notice mint NFT with specific tokenId
     * @dev tokenId must not exist
     */
    function mintWithSpecificTokenId(address to, uint256 _tokenId) public {
        // 使用指定的 tokenId mint NFT
        _safeMint(to, _tokenId);

        // 初始化 tokenId 对应的 Mood（假设初始状态为 HAPPY）
        s_tokenIdToMood[_tokenId] = Mood.HAPPY;
        s_tokenCounter++;
    }
}
