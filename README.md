# Requirements
  * Truffle 5.0.1 (web3.js 1.0.0)
  * Ganache-cli 6.1.6 (ganache-core: 2.1.5)


# Set Up
  * `$ npm install`
  * `$ npm run chain`
  * `$ npm run test`  


# Assumptions
1. Daily limit works in periods of 24 hours, not in function of calendar days.

2. All payees have the same daily limit.

3. If daily limit is lowered, and current payee's daily spent is higher that this new limit, payees will have to wait until the 24h periods ends to be able to withdraw again.

4. Payees can be added in batches, however they can be removed only one by one.


# Notes
1. `addPayees()` might reach block gas limit if payees array is to long. Owner should take care of this situation and consider to populate the wallet in batches if necessary.

2. **SafeMath** library is not used since there are only 2 situations where it might be applied but I considered it was unnecessary:
  * `payees[msg.sender].dailySpent += _value;`: Input `_value` is previously checked with modifier `enoughBalance()`.
  * `remainingAmount = dailyLimit - payees[_payee].dailySpent;`: This subtraction will happen only if `dailyLimit > payees[_payee].dailySpent`.

3. Reentrancy attacks are not possible because of making use of `transfer()` instead of `call()`.   

4. Enough Events are emitted to make possible to interact with the wallet from a UI.

5. Contracts **Ownable.sol** and **Pausable.sol** belongs to OpenZeppelin.

6. *Blacklisted* term is used to define *Not Whitelisted*.


# Enhancements
1. Might be considered to use a Upgradeability pattern like **Unstructured storage**.

2. Use Security tools and audit the smart contracts.

3. Reach 100% test coverage.

4. Might be considered to lose clarity in `payeeWithdraws()` in favor of saving GAS to benefit the users.
