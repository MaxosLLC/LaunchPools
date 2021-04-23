// We require the Hardhat Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hh = require("hardhat");

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

  const currentTime = Math.round(Date.now() / 1000) + 36000;
  const LaunchPool = await hh.ethers.getContractFactory("LaunchPool");
  const launchPool = await LaunchPool.deploy([mockERC20.address], "testPool1", 100000, 1000000, currentTime);

  await launchPool.deployed();

  console.log("MockERC20:", mockERC20.address, "LaunchPool:", launchPool.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
