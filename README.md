# StakeVault Contract

This repo contains all the contracts for Presail. It uses hardhat to aid in development.

### Setting up:

Install all dependencies: `npm i`.

### Running the tests

`npx hardhat test`.

### Running a local node:

In order to test the system e2e, a local blockchain must be running.

1. Run the local blockchain: `npx hardhat node`.
2. Compile and deploy all contracts to this network: `npx hardhat run --network localhost scripts/deploy.ts`.

This will print out the addresses where the contracts where deployed. These values will be
used in the frontend.

At this point, you have a local blockchain running on `localhost:8545` ready to accept connections.
