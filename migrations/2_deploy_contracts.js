const LaunchBoard = artifacts.require('./LaunchBoard.sol')
const LaunchPool = artifacts.require('./LaunchPool.sol')
const Stake = artifacts.require('./Stake.sol')

module.exports = (deployer, network, accounts) =>
  deployer.then(async () => {
    await deployer.deploy(LaunchBoard)
    await deployer.deploy(LaunchPool)
    await deployer.deploy(Stake)

    const launchBoard = await LaunchBoard.deployed()
    await LaunchPool.deployed()
    await Stake.deployed()

    await launchBoard.createLaunchPool('Test')
  })