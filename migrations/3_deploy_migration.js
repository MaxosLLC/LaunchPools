
const FakePrivi = artifacts.require('FakePrivi')
const FakeBAL = artifacts.require('FakeBAL')
const FakeBAT = artifacts.require('FakeBAT')
const FakeCOMP = artifacts.require('FakeCOMP')
const FakeDAI = artifacts.require('FakeDAI')
const FakeLINK = artifacts.require('FakeLINK')
const FakeMKR = artifacts.require('FakeMKR')
const FakeUNI = artifacts.require('FakeUNI')
const FakeUSDT = artifacts.require('FakeUSDT')
const FakeWBTC = artifacts.require('FakeWBTC')
const FakeWETH = artifacts.require('FakeWETH')
const FakeYFI = artifacts.require('FakeYFI')

module.exports = async function(deployer, networks, accounts) {
  if (networks !== 'mainnet') {
    await deployer.deploy(FakePrivi)
    await deployer.deploy(FakeBAL)
    await deployer.deploy(FakeBAT)
    await deployer.deploy(FakeCOMP)
    await deployer.deploy(FakeDAI)
    await deployer.deploy(FakeLINK)
    await deployer.deploy(FakeMKR)
    await deployer.deploy(FakeUNI)
    await deployer.deploy(FakeUSDT)
    await deployer.deploy(FakeWBTC)
    await deployer.deploy(FakeWETH)
    await deployer.deploy(FakeYFI)
  }
}
