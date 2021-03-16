const LaunchBoard = artifacts.require("LaunchBoard");
const LaunchPool = artifacts.require('LaunchPool.sol')
const Stake = artifacts.require('Stake.sol')

module.exports = (deployer, network, accounts) =>
  deployer.then(async () => {
    await deployer.deploy(LaunchBoard, accounts[0], '0x61A6EA2A7Fd8e3a30A16B7CBA8de3A6F75089094')
    await deployer.deploy(LaunchPool)
    await deployer.deploy(Stake, '0x61A6EA2A7Fd8e3a30A16B7CBA8de3A6F75089094')

    const launchBoard = await LaunchBoard.deployed()
    await LaunchPool.deployed()
    await Stake.deployed()

    await launchBoard.createLaunchPool('0x0')
});
