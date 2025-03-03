// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// These let us create NFTs and set royalties—ERC721 includes metadata like tokenURI
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/interfaces/IERC2981.sol";

interface ILayerZeroReceiver {
    function lzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) external;
}

interface ILayerZeroEndpoint {
    function send(uint16 _dstChainId, bytes calldata _destination, bytes calldata _payload, address payable _refundAddress, address _zroPaymentAddress, bytes calldata _adapterParams) external payable;
}

abstract contract NonblockingLzApp {
    ILayerZeroEndpoint public layerZeroEndpoint;
    mapping(uint16 => bytes) public trustedDestinations;

    constructor(address _endpoint) {
        layerZeroEndpoint = ILayerZeroEndpoint(_endpoint);
    }

    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _payload) internal virtual;

    function lzReceive(uint16 _srcChainId, bytes calldata, uint64, bytes calldata _payload) external {
        require(msg.sender == address(layerZeroEndpoint), "Only LayerZero can call this!");
        _nonblockingLzReceive(_srcChainId, _payload);
    }

    // Set the trusted Base Sepolia contract address after deployment
    function setTrustedDestination(uint16 chainId, bytes calldata destinationAddress) external {
        trustedDestinations[chainId] = destinationAddress;
    }
}

// This receives and mints identical Karu NFTs on Hyper EVM
contract HyperEVMNFTBridge is ERC721, IERC2981, NonblockingLzApp {
    address public royaltyWallet; // Where 5% royalties go—set to a team wallet
    uint256 public royaltyPercent = 500; // 5% (500 basis points)
    mapping(uint256 => address) public originalOwners; // Tracks who owned it on Base
    mapping(uint256 => string) public tokenMetadata; // Keeps Karu NFT traits

    event NFTMinted(address indexed owner, uint256 tokenId);

    // Deploy with Hyper EVM’s endpoint and your team wallet
    constructor(address layerZeroEndpointAddress, address teamRoyaltyWallet) 
        ERC721("NewKaru", "NKARU") 
        NonblockingLzApp(layerZeroEndpointAddress) 
    {
        royaltyWallet = teamRoyaltyWallet;
        trustedDestinations[40245] = abi.encodePacked(address(this)); // Base Sepolia
    }

    // Receives the NFT data from Base and mints it here with the same traits
    function _nonblockingLzReceive(uint16 sourceChainId, bytes memory payload) internal override {
        require(sourceChainId == 40245, "Only Base Sepolia can send here!");
        // Use tokenURIData to avoid shadowing tokenURI function
        (address owner, uint256 tokenId, string memory tokenURIData) = abi.decode(payload, (address, uint256, string));
        require(originalOwners[tokenId] == address(0), "This NFTs already minted!");
        _mint(owner, tokenId);
        tokenMetadata[tokenId] = tokenURIData; // Copies Karu NFT traits
        originalOwners[tokenId] = owner;
        emit NFTMinted(owner, tokenId);
    }

    // For testing in Remix—call with 40245 and payload
    function simulateNonblockingLzReceive(uint16 sourceChainId, bytes memory payload) external {
        _nonblockingLzReceive(sourceChainId, payload);
    }

    // Returns the Karu NFT’s traits—same as on Base
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireOwned(tokenId);
        return tokenMetadata[tokenId];
    }

    // Sets 5% royalties—team wallet gets paid on sales
    function royaltyInfo(uint256, uint256 salePrice) external view override returns (address, uint256) {
        return (royaltyWallet, (salePrice * royaltyPercent) / 10000);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || 
               super.supportsInterface(interfaceId); // ERC721 includes IERC721Metadata
    }
}