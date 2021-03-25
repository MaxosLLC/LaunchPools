let LaunchBoard = artifacts.require('contracts/LaunchBoard.sol')

contract('LaunchBoard', accounts => {
  let launchBoard

  beforeEach(async () => {
    launchBoard = await LaunchBoard.new({from: accounts[0]})
  })

  it('LaunchBoard - Create Launch Pool', async () => {
    let lp = await launchBoard.createLaunchPool('Maxos', 'http://maxos.studio/', 1615909020, 1, 100)
    assert.equal(lp.logs[1].event, 'LaunchPoolCreated')
  })
})
