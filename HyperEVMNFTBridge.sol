// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

contract KaruBridge is ERC721, Ownable, IERC2981 {
    address public constant BASE_BRIDGE = 0xF021FF101D7580797A4C2EA871293cC9BFbB1449;
    string private _baseTokenURI;
    address public royaltyWallet;
    uint256 public constant ROYALTY_PERCENT = 500; // 5%

    constructor(address _delegate, address _royaltyWallet)
        ERC721("KaruBridge", "KBRG")
        Ownable(_delegate)
    {
        royaltyWallet = _royaltyWallet;
    }

    // Mint using OpenZeppelin's _safeMint
    function mint(address to, uint256 tokenId) external onlyOwner {
        _safeMint(to, tokenId); // Standard, reverts if exists
    }

    // Set base URI for metadata
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
    }

    // Override base URI
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    // Royalty info (ERC-2981)
    function royaltyInfo(uint256, uint256 salePrice) external view override returns (address, uint256) {
        return (royaltyWallet, (salePrice * ROYALTY_PERCENT) / 10000);
    }

    // Interface support
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }
}
