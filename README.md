## DAMN VULNERABLE DEFI - ATTACK

This will be a collection of my solutions for each level of this blockchain security game.

---

![](cover.png)

**A set of challenges to learn offensive security of smart contracts in Ethereum.**

Featuring flash loans, price oracles, governance, NFTs, lending pools, smart contract wallets, timelocks, and more!

### Play

Visit [damnvulnerabledefi.xyz](https://damnvulnerabledefi.xyz)

### Disclaimer

All Solidity code, practices and patterns in this repository are DAMN VULNERABLE and for educational purposes only.

DO NOT USE IN PRODUCTION.

---

## Solutions

### 1 - Unstoppable

- The contract checks for deposited funds in line 40 of UnstoppableLender contract. If the contract receives external funds, the poolBalance will no longer be equal to balanceBefore and will cause the error thus stopping flashloan() function and making it unuseable.

### 2 - Naive receiver

- Anyone can call the flashLoan() function in NaiveReceiverLenderPool contract since the check is only available in the FlashLoanReceiver contract. Calling the function multiple times with the User address as borrower will drain it with the Fixed fee. Calling the function ten times since fixed fee is 1 ETH.

### 3 - Truster

- Attacker can approve a maliscious contract to drain the DVT tokens.
