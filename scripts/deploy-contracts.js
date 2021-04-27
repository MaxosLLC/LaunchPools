// We require the Hardhat Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { BigNumber } = require("@ethersproject/bignumber");
const hh = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile 
  // manually to make sure everything is compiled
  await hh.run('compile');

  // const MockERC20 = await hh.ethers.getContractFactory("MockERC20");
  // const mockERC20 = await MockERC20.deploy(100);

  // await mockERC20.deployed();
  const MOCKERC20 = "0xeA096Ba8979893CF64B7b67eF84BcD9C0cDe925c";
  // const DAI = "0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa";
  // const USDC = "0x75b0622cec14130172eae9cf166b92e5c112faff";

  const currentTime = Math.round(Date.now() / 1000) + (3600 * 24 * 200);
  const LaunchPool = await hh.ethers.getContractFactory("LaunchPool");

  const minAmount = BigNumber.from("5000000000000000000000000");
  const maxAmount = BigNumber.from("1000000000000000000000000000000000");
  const launchPool = await LaunchPool.deploy([MOCKERC20], "testPool1", minAmount.toHexString(), maxAmount.toHexString(), currentTime);

  await launchPool.deployed();

  console.log("LaunchPool:", launchPool.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
