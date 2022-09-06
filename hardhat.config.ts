import { HardhatRuntimeEnvironment, HardhatUserConfig } from 'hardhat/types'
import { task } from 'hardhat/config'
import '@typechain/hardhat'
import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'
import '@nomiclabs/hardhat-etherscan'
import 'hardhat-contract-sizer'
import 'hardhat-gas-reporter'
import * as dotenv from 'dotenv'
dotenv.config()

task("accounts", "Prints the list of accounts", async (args, hre: HardhatRuntimeEnvironment) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
    compilers: [
      {
        version: '0.8.7',
        settings: {},
      },
    ],
  },
  networks: {
    hardhat: {
      gas: 'auto',
      allowUnlimitedContractSize: true,
      chainId: 1337
    },
    localhost: {
      allowUnlimitedContractSize: true,
      blockGasLimit: 87500000000,
      url: 'http://127.0.0.1:8545/',
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : []
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY ? process.env.ETHERSCAN_API_KEY : ""
  },
  typechain: {
    outDir: 'types',
    target: 'ethers-v5',
  }, 
  gasReporter: {
    enabled: (process.env.REPORT_GAS) ? true : false,
    currency: 'USD'
  }
};

export default config;