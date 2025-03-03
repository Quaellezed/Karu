// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// This gives us basic NFT functionality, including tokenURI—mimics Karu NFT
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";

contract DummyNFT is ERC721 {
    mapping(uint256 => string) private _tokenURIs; // Stores Karu-like metadata

    // Deploy this on Base Sepolia to test locking—sets up a dummy Karu NFT
    constructor() ERC721("DummyKaru", "DKARU") {}

    // Mint a test NFT—use your Karu token ID (e.g., 4) or new ones
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    // Optional: Set the URI to match a real Karu NFT from Base Mainnet
    function setTokenURI(uint256 tokenId, string memory uri) external {
        _tokenURIs[tokenId] = uri;
    }

    // Returns the metadata—same as Karu NFT’s tokenURI
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireOwned(tokenId);
        return _tokenURIs[tokenId];
    }
}