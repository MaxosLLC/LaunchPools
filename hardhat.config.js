require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan")

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

const INFURA_API_KEY = 'e1deb8ec2a8e4c668b98a3cfb66b2d1e'
const RINKEBY_PRIVATEKEY = '6cc9076505a74fe4b1d077770f54470e'
// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: 'hardhat',
  solidity: "0.8.4",
  networks: {
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${INFURA_API_KEY}`,
      accounts: ['bac33fedfdb37fd1c88cf996f31282be32cae56f6a4ef8f3ca1e4cbd470baad3']
    },
  },

  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: "EEGYGWMMI6J83A3QNPDDV6EDJH446HHRVP"
  }
};
