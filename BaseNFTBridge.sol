// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract KaruBaseBridge is Ownable, ReentrancyGuard {
    IERC721 internal immutable innerToken;
    mapping(uint256 => bool) public locked;

    event Locked(uint256 indexed tokenId, address indexed sender);

    constructor(address _delegate) Ownable(_delegate) {
        innerToken = IERC721(0x5cB9cF52392Bb4b927A8eA1671f01B6009e81A93); // DummyNFT
    }

    function token() external view returns (address) {
        return address(innerToken);
    }

    function approvalRequired() external pure returns (bool) {
        return true;
    }

    function bridge(uint256 tokenId) external nonReentrant {
        require(!locked[tokenId], "Token already bridged");
        require(innerToken.ownerOf(tokenId) == msg.sender, "Not token owner");
        require(
            innerToken.getApproved(tokenId) == address(this) || 
            innerToken.isApprovedForAll(msg.sender, address(this)), 
            "Not approved"
        );

        innerToken.transferFrom(msg.sender, address(this), tokenId);
        locked[tokenId] = true;

        emit Locked(tokenId, msg.sender);
    }

    // Explicitly block any transfer attempts
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        revert("Contract does not accept ERC721 tokens");
    }

    // Prevent owner from moving NFTs, no unused param
    function recoverToken() external view onlyOwner {
        revert("Tokens are permanently locked");
    }
}
