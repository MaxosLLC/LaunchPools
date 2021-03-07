const LaunchPool = artifacts.require('./LaunchPool.sol')
const Stake = artifacts.require('./Stake.sol')

module.exports = (deployer, network, accounts) =>
  deployer.then(async () => {

    await deployer.deploy(LaunchPool)
    await deployer.deploy(Stake)

    const launchPool = await LaunchPool.deployed()
    await Stake.deployed()

    await launchPool.createLaunchPool('Test')
  })