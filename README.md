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

### 4 - Side entrance

- Attacker can call flashloan and deposit the amount then immediatly withdraw.

### 5 - The Rewarder

- When the new rounds of rewards start, Attacker will get a flashloan of all the DVT tokens and then deposit to the rewarder pool contract thus will trigger the distribute all to the Attacker. Then immediately withdraw to payy all the tokens.

### 6 - Selfie

- Attacker can drain all the funds from the pool by activating the drainAllFunds() function. Attacker needs to meet use the SimpleGovernance contract and satisfy its condition of having half the governance token in the snapshot. It could be done by borrowing in lending pool then taking a snapshot then run executeAction() function after the ACTION_DELAY_IN_SECONDS has passed.

### 7 - Compromised

- The strange snippet was actually the private keys and thus with that the atcker can manipulate the oracle to manipulate the price to zero then buy the nft then manipulate the price back to something expensive then sell the nft.

### 8 - Puppet

- Attacker can manipulate the price of the token from the oracle function by manipulating the balance of the Uniswap pool. Attacker exchanges all his tokens to ETH so that the price of tokens drop and attacker may now borrow all the tokens with the new discounted price of around 19-20 ETH thus draining the contract of all of its token.

### 9 - Puppet-v2

- Very similar to above that Attcker may once again manipulate oracle price by swapping the tokens then borrowing or getting a loan with no plans of paying it back thus efectively draining all the DVT from the contract.

### 10 - Free Rider

- There is a vulnerability with the buyMany() function in FreeRiderNFTMarketplace contract in which attacker may buy multiple nft with only paying the price of one. The contract will pay for the unpaid NFT by the attacker acting as buyer. Using a flashloan the player can barrow the needed fund and both be the buyer and seller to buy all of the NFT. This will also effectively drain the contract's ETH since it is paying for the unpaid eventually then forward to FreeRiderBuyer contract to claim the reward.
