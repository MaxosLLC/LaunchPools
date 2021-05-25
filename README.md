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

These are the most important methods from the `LaunchPoolTracker.sol` contract. Please refer to the source code for more
details

`stake(address token, uint256 amount)` - Adds a new stake. This stake is given an id. To retrieve this id, you need
to listen inspect the `Staked` event. Only ERC20 tokens are allowed. Transfers from the token to the contract.

`unstake(uint256 stakeId)` - Remove stake. Should specify the stake id.

`setOffer(string memory offerUrl_)` - Set the offer and start the timer.

`commit(uint256 stakeId)` - Commit the desired stake.

`stakesOf(address account)` - Total stakes of an address.

`canRedeemOffer()` - Checks if the offer can be redeemed.

`redeemOffer()` - Tries to redeem the offer. Checks all commitments and
transfers all the staked funds to an address set for the StakeVault contract.

Kovan Contract Adresses:

```
ERC20 = "0xeA096Ba8979893CF64B7b67eF84BcD9C0cDe925c"
DAI   = "0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa"
USDC  = "0x75b0622cec14130172eae9cf166b92e5c112faff"
LaunchPool: "0x1E8B22F165d253cC0622fEB7F2374f7180CA6C54"
```
