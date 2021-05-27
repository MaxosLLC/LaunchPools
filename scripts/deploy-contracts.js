// We require the Hardhat Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { BigNumber } = require("@ethersproject/bignumber");
const hh = require("hardhat");

const SPONSOR_ADDRESS = '0xFe2de4c96C992136eadcF2EdaDF74a091fA4267C';

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile 
  // manually to make sure everything is compiled
  await hh.run('compile');

  const MockERC20 = await hh.ethers.getContractFactory("MockERC20");
  const mockERC20 = await MockERC20.deploy(100);

  await mockERC20.deployed();
  // const MOCKERC20 = "0xeA096Ba8979893CF64B7b67eF84BcD9C0cDe925c";
  // const DAI = "0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa";
  // const USDC = "0x75b0622cec14130172eae9cf166b92e5c112faff";

  const StakeVault = await hh.ethers.getContractFactory("StakeVault");
  const stakeVault = await StakeVault.deploy(SPONSOR_ADDRESS);
  await stakeVault.deployed();

  const LaunchPoolTracker = await hh.ethers.getContractFactory("LaunchPoolTracker");

  const launchPoolTracker = await LaunchPoolTracker.deploy(
    [mockERC20.address], 
    stakeVault.address
  );

  const minAmount = BigNumber.from("5000000000000000000000000");
  const maxAmount = BigNumber.from("1000000000000000000000000000000000");

  await launchPoolTracker.addLaunchPool(
    "testpool1",
    60 * 60 * 24 * 7, // 7 days
    86400,
    1000000,
    1000000000,
  );

  // const launchPool = await LaunchPoolTracker.deploy(
  //   [mockERC20.address],
  //   "testPool1",
  //   60 * 60 * 24 * 365,
  //   60 * 60 * 24 * 7,
  //   minAmount.toHexString(),
  //   maxAmount.toHexString(),
  //   stakeVault.address
  // );

  await launchPoolTracker.deployed();

  console.log("MockERC20:", mockERC20.address,
    "\nStakeVault:", stakeVault.address,
    "\nLaunchPool:", launchPoolTracker.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
