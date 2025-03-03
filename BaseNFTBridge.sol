// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/IERC721Metadata.sol";

interface ILayerZeroReceiver {
    function lzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) external;
}

interface ILayerZeroEndpoint {
    function send(uint16 _dstChainId, bytes calldata _destination, bytes calldata _payload, address payable _refundAddress, address _zroPaymentAddress, bytes calldata _adapterParams) external payable;
}

abstract contract NonblockingLzApp {
    ILayerZeroEndpoint public layerZeroEndpoint;
    mapping(uint16 => bytes) public trustedDestinations;
    mapping(uint16 => mapping(bytes => mapping(uint64 => bytes32))) public failedMessages;
    bool private isLocked;

    event MessageFailed(uint16 sourceChainId, bytes sourceAddress, uint64 nonce, bytes payload);

    modifier noReentrancy() {
        require(!isLocked, "Hold up, already processing!");
        isLocked = true;
        _;
        isLocked = false;
    }

    constructor(address _endpoint) {
        require(_endpoint != address(0), "Need a valid endpoint!");
        layerZeroEndpoint = ILayerZeroEndpoint(_endpoint);
    }

    function sendAcrossChain(
        uint16 destinationChainId,
        bytes memory payload,
        address payable refundAddress,
        address zroPaymentAddress,
        bytes memory adapterParams,
        uint256 ethAmount
    ) internal noReentrancy {
        bytes memory trustedAddress = trustedDestinations[destinationChainId];
        require(trustedAddress.length > 0, "No trusted destination set for this chain!");
        layerZeroEndpoint.send{value: ethAmount}(destinationChainId, trustedAddress, payload, refundAddress, zroPaymentAddress, adapterParams);
    }

    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal virtual;

    function lzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) external {
        require(msg.sender == address(layerZeroEndpoint), "Only LayerZero can call this!");
        _nonblockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    function setTrustedDestination(uint16 chainId, bytes calldata destinationAddress) external {
        trustedDestinations[chainId] = destinationAddress;
    }

    function getTrustedDestination(uint16 chainId) external view returns (bytes memory) {
        return trustedDestinations[chainId];
    }
}

contract BaseNFTBridge is NonblockingLzApp {
    address public karuNFTContract;
    mapping(uint256 => bool) public isLocked;

    event NFTLocked(address indexed owner, uint256 tokenId);

    constructor(address layerZeroEndpointAddress, address karuNFTAddress) NonblockingLzApp(layerZeroEndpointAddress) {
        karuNFTContract = karuNFTAddress;
    }

    function lockNFT(uint256 tokenId) external payable {
        require(IERC721(karuNFTContract).ownerOf(tokenId) == msg.sender, "You dont own this NFT!");
        require(!isLocked[tokenId], "This NFT is already locked!");
        require(msg.value > 0, "Must send ETH for gastry 0.01 ETH!");
        IERC721(karuNFTContract).transferFrom(msg.sender, address(this), tokenId);
        isLocked[tokenId] = true;
        string memory tokenURI = IERC721Metadata(karuNFTContract).tokenURI(tokenId);
        bytes memory payload = abi.encode(msg.sender, tokenId, tokenURI);
        // Increased gas for Hyper EVM—500k
        bytes memory adapterParams = abi.encodePacked(uint16(1), uint256(500000));
        sendAcrossChain(40362, payload, payable(msg.sender), address(0x0), adapterParams, msg.value);
        emit NFTLocked(msg.sender, tokenId);
    }

    function _nonblockingLzReceive(uint16, bytes memory, uint64, bytes memory) internal override {}
}