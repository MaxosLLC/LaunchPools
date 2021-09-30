import { task } from "hardhat/config";
import '@typechain/hardhat'
import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'

task("accounts", "Prints the list of accounts", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

export default {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      chainId: 1337
    }
  },
  solidity: "0.8.4",
  typechain: {
    outDir: "types",
    target: "ethers-v5"
  }
};
