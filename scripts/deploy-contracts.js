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
  const accounts = await ethers.getSigners();

  // const MockERC20 = await hh.ethers.getContractFactory("MockERC20");
  // const mockERC20 = await MockERC20.deploy(100);

  // await mockERC20.deployed();
  const USDC = "0xeb8f08a975ab53e34d8a0330e0d34de942c95926";
  const CUSDC = "0x5b281a6dda0b271e91ae35de655ad301c976edb1";
  const YVUSDC = "0x559af2944335b5cd65f78ab02123738bc57cfd7d";
  const WETH = "0xc778417e063141139fce010982780140aa0cd5ab";
  const WBTC = "0x577d296678535e4903d59a4c929b718e1d575e0a";

  const StakeVault = await hh.ethers.getContractFactory("StakeVault", {from: accounts[0]});
  const stakeVault = await StakeVault.deploy();
  await stakeVault.deployed();


  const LaunchPoolTracker = await hh.ethers.getContractFactory("LaunchPoolTracker", {from: accounts[0]});

  const launchPoolTracker = await LaunchPoolTracker.deploy([ USDC, CUSDC, YVUSDC, WETH, WBTC ], stakeVault.address);


  // const minAmount = BigNumber.from("5000000000000000000000000");
  // const maxAmount = BigNumber.from("1000000000000000000000000000000000");

  // await mockERC20.approve(stakeVault.address, 100);

  await launchPoolTracker.deployed();

  // await launchPoolTracker.addPool('poolName', 1909763066, 1909763066, minAmount, maxAmount);

  // await launchPoolTracker.addPool('poolName3', 1909763066, 1909763066, minAmount, maxAmount);

  // await launchPoolTracker.addPool('poolName1', 1909763066, 1909763066, minAmount, maxAmount);

  // await launchPoolTracker.addPool('poolName2', 1909763066, 1909763066, minAmount, maxAmount);

  await stakeVault.setPoolContract(launchPoolTracker.address)


  console.log("StakeVault:", stakeVault.address,
    "\nLaunchPoolTracker:", launchPoolTracker.address);
  
    console.log({
      presale: `npx hardhat verify --network ${network} ${stakeVault.address}`});
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
