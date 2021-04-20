# Launch Pools Contracts

This repo contains all the contracts for launchpools. It uses hardhat to aid in development.

### Setting up:

Install all dependencies: `npm i`. Then you can run the tests `npx hardhat test`.

### Running a local node:

In order to test the system e2e, a local blockchain must be running. 

1. Run the local blockchain: `npx hardhat node`.
2. Compile and deploy all contracts to this network: `npx hardhat run --network localhost scripts/deploy-contracts.js`.

At this point, you have a local blockchain running on `localhost:8545` ready to accept connections.


