//SPDX-License-Identifier:MIT
pragma solidity 0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract MoodNft is ERC721, ERC721Burnable {
    //////////////////////////////////////////
    ///////////   errors         /////////////
    //////////////////////////////////////////
    error MoodNft__CannotFlipMoodNotOwner();

    //////////////////////////////////////////
    ///////////   Variables      /////////////
    //////////////////////////////////////////

    enum Mood {
        HAPPY,
        SAD
    }

    uint256 public s_tokenCounter;
    string private s_happySvgImageUri;
    string private s_sadSvgImageUri;

    mapping(uint256 => Mood) public s_tokenIdToMood;

    //////////////////////////////////////////
    ///////////   Events        /////////////
    //////////////////////////////////////////

    event FlippedMood(uint256 indexed tokenId, Mood mood);

    constructor(string memory happySvgImageUri, string memory sadSvgImageUri, string memory name, string memory symbol)
        ERC721(name, symbol)
    {
        s_tokenCounter = 0;
        s_happySvgImageUri = happySvgImageUri;
        s_sadSvgImageUri = sadSvgImageUri;
    }

    //////////////////////////////////////////
    /////////// external functions /////////////
    //////////////////////////////////////////
    /**
     * @notice mint NFT
     * @dev tokenId must not exist
     */
    function mintNft() external virtual {
        _safeMint(msg.sender, s_tokenCounter);
        s_tokenIdToMood[s_tokenCounter] = Mood.HAPPY;
        s_tokenCounter++;
    }

    /**
     * @notice flip mood to change the nft image
     * @param tokenId token id
     * @dev only owner can flip mood
     */
    function flipMood(uint256 tokenId) external {
        if (!_isAuthorized(ownerOf(tokenId), msg.sender, tokenId)) {
            revert MoodNft__CannotFlipMoodNotOwner();
        }

        if (s_tokenIdToMood[tokenId] == Mood.HAPPY) {
            s_tokenIdToMood[tokenId] = Mood.SAD;
            emit FlippedMood(tokenId, Mood.SAD);
        } else {
            s_tokenIdToMood[tokenId] = Mood.HAPPY;
            emit FlippedMood(tokenId, Mood.HAPPY);
        }
    }

    //////////////////////////////////////////
    /////////// internal functions ///////////
    //////////////////////////////////////////

    /**
     *  @notice
     */
    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    //////////////////////////////////////////
    ///// public view&pure functions /////////
    //////////////////////////////////////////

    /**
     * @notice get token uri
     * @param tokenId token id
     * @return token uri
     *
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        string memory imageURI;

        if (s_tokenIdToMood[tokenId] == Mood.HAPPY) {
            imageURI = s_happySvgImageUri;
        } else {
            imageURI = s_sadSvgImageUri;
        }

        return string(
            abi.encodePacked(
                _baseURI(),
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name": "',
                            name(),
                            '", "description": "An NFT that reflects the owner mood.","attributes": [{"trait_type": "moodiness", "value": 100}], "image": "',
                            imageURI,
                            '"}'
                        )
                    )
                )
            )
        );
    }

    /**
     *  @notice get happy svg image uri
     *  @return happy svg image uri
     */
    function getHappySvgImageUri() external view returns (string memory) {
        return s_happySvgImageUri;
    }

    /**
     * @notice get sad svg image uri
     * @return sad svg image uri
     */
    function getSadSvgImageUri() external view returns (string memory) {
        return s_sadSvgImageUri;
    }

    /**
     * @notice get base uri
     * @return base uri
     */
    function getBaseURI() external pure returns (string memory) {
        return _baseURI();
    }
}
