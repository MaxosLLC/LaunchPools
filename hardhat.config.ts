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
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : []
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : []
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : []
    },
    polygon: {
      url: `https://rpc-mainnet.maticvigil.com/v1/${process.env.INFURA_PROJECT_ID}`,
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : []
    },
    mumbai: {
      url: `https://rpc-mumbai.maticvigil.com/`,
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : []
    }
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY ? process.env.ETHERSCAN_API_KEY : "",
      rinkeby: process.env.ETHERSCAN_API_KEY ? process.env.ETHERSCAN_API_KEY : "",
      goerli: process.env.ETHERSCAN_API_KEY ? process.env.ETHERSCAN_API_KEY : "",

      polygon: process.env.POLYGONSCAN_API_KEY ? process.env.POLYGONSCAN_API_KEY : "",
      mumbai: process.env.POLYGONSCAN_API_KEY ? process.env.POLYGONSCAN_API_KEY : ""
    }, 
    customChains: [
      {
        network: "mainnet",
        chainId: 1,
        urls: {
          apiURL: "https://api.etherscan.io/api",
          browserURL: "https://etherscan.io"
        }
      },
      {
        network: "rinkeby",
        chainId: 4,
        urls: {
          apiURL: "https://api-rinkeby.etherscan.io/api",
          browserURL: "https://rinkeby.etherscan.io"
        }
      },
      {
        network: "goerli",
        chainId: 5,
        urls: {
          apiURL: "https://api-goerli.etherscan.io/api",
          browserURL: "https://goerli.etherscan.io"
        }
      },
      {
        network: "polygon",
        chainId: 137,
        urls: {
          apiURL: "https://api.polygonscan.com/api",
          browserURL: "https://polygonscan.com/"
        }
      },
      {
        network: "mumbai",
        chainId: 80001,
        urls: {
          apiURL: "https://api-testnet.polygonscan.com/api",
          browserURL: "https://mumbai.polygonscan.com/"
        }
      }
    ] 
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