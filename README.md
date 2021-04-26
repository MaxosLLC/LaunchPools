# Launch Pools Contracts

This repo contains all the contracts for launchpools. It uses hardhat to aid in development.

### Setting up:

Install all dependencies: `npm i`.

### Running the tests

`npx hardhat test`.

### Running a local node:

In order to test the system e2e, a local blockchain must be running.

1. Run the local blockchain: `npx hardhat node`.
2. Compile and deploy all contracts to this network: `npx hardhat run --network localhost scripts/deploy-contracts.js`.

This will print out the addresses where the contracts where deployed. These values will be
used in the frontend.

At this point, you have a local blockchain running on `localhost:8545` ready to accept connections.

### API

These are the most important methods from the `LaunchPool.sol` contract. Please refer to the source code for more
details

`stake(token, amount)` - Staking token. Only ERC20 tokens are allowed. Transfers from the token to the contract.
`unstake(token)` - Unstake token. Transfers back to the token holder.

`minCommitment`, `maxCommitment` and `name` - Public members.

`stakesOf(account, token)` - token amount staked by account.
`totalStakesOf(account)` - total amount of tokens staked by account.
`totalStakes()` - total amount staked by all accounts.
`isFunded()` - Returns true if `totalStakes()` is >= `minCommitment`

Kovan Contract Adresses:

```
ERC20 = "0xeA096Ba8979893CF64B7b67eF84BcD9C0cDe925c"
DAI   = "0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa"
USDC  = "0x75b0622cec14130172eae9cf166b92e5c112faff"
LaunchPool: "0x35111fe40e1F4d8252821F382696665AD7168612"
```
