// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../DamnValuableNFT.sol";

/**
 * @title FreeRiderNFTMarketplace
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract FreeRiderNFTMarketplace is ReentrancyGuard {
    using Address for address payable;

    DamnValuableNFT public token;
    uint256 public amountOfOffers;

    // tokenId -> price
    mapping(uint256 => uint256) private offers;

    event NFTOffered(address indexed offerer, uint256 tokenId, uint256 price);
    event NFTBought(address indexed buyer, uint256 tokenId, uint256 price);

    constructor(uint8 amountToMint) payable {
        require(amountToMint < 256, "Cannot mint that many tokens");
        token = new DamnValuableNFT();

        for (uint8 i = 0; i < amountToMint; i++) {
            token.safeMint(msg.sender);
        }
    }

    function offerMany(
        uint256[] calldata tokenIds,
        uint256[] calldata prices
    ) external nonReentrant {
        require(tokenIds.length > 0 && tokenIds.length == prices.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _offerOne(tokenIds[i], prices[i]);
        }
    }

    function _offerOne(uint256 tokenId, uint256 price) private {
        require(price > 0, "Price must be greater than zero");

        require(
            msg.sender == token.ownerOf(tokenId),
            "Account offering must be the owner"
        );

        require(
            token.getApproved(tokenId) == address(this) ||
                token.isApprovedForAll(msg.sender, address(this)),
            "Account offering must have approved transfer"
        );

        offers[tokenId] = price;

        amountOfOffers++;

        emit NFTOffered(msg.sender, tokenId, price);
    }

    function buyMany(
        uint256[] calldata tokenIds
    ) external payable nonReentrant {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _buyOne(tokenIds[i]);
        }
    }

    function _buyOne(uint256 tokenId) private {
        uint256 priceToPay = offers[tokenId];
        require(priceToPay > 0, "Token is not being offered");

        require(msg.value >= priceToPay, "Amount paid is not enough");

        amountOfOffers--;

        // transfer from seller to buyer
        token.safeTransferFrom(token.ownerOf(tokenId), msg.sender, tokenId);

        // pay seller
        payable(token.ownerOf(tokenId)).sendValue(priceToPay);

        emit NFTBought(msg.sender, tokenId, priceToPay);
    }

    receive() external payable {}
}

import "../DamnValuableToken.sol";
import "../DamnValuableNFT.sol";
import "../free-rider/FreeRiderBuyer.sol";
import "../free-rider/FreeRiderNFTMarketplace.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";

contract FreeRiderAttack is IUniswapV2Callee, IERC721Receiver {
    address immutable attacker;
    IUniswapV2Pair immutable uniswapPair;
    FreeRiderNFTMarketplace immutable nftMarketplace;
    IWETH immutable weth;
    IERC721 immutable nft;
    address freeRiderBuyer;
    uint256 nftPrice;

    constructor(
        IUniswapV2Pair _uniswapPair,
        FreeRiderNFTMarketplace _nftMarketplace,
        IWETH _weth,
        address _freeRiderBuyer,
        uint256 _nftPrice
    ) {
        attacker = msg.sender;
        uniswapPair = _uniswapPair;
        nftMarketplace = _nftMarketplace;
        weth = _weth;
        nft = _nftMarketplace.token();
        freeRiderBuyer = _freeRiderBuyer;
        nftPrice = _nftPrice;
    }

    //TODO: 1 flashloan for 15 weth
    function hack() external {
        // need to pass some data to trigger uniswapV2Call
        // borrow 15 ether of WETH
        bytes memory data = abi.encode(uniswapPair.token0(), nftPrice);
        uniswapPair.swap(nftPrice, 0, address(this), data);
    }

    // 2. uniswap weth to eth
    function uniswapV2Call(
        address,
        uint,
        uint,
        bytes calldata
    ) external override {
        weth.withdraw(120 ether);
    }
    // 3. buy all the NFT
    // 4. send to FreeRiderBuyer contract
    // 5. repay loan to uniswap
}
