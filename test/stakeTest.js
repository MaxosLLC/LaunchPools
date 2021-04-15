let LaunchBoard = artifacts.require('contracts/Stake.sol')

contract('Stake', accounts => {
  let stake

  beforeEach(async () => {
    stake = await Stake.new({from: accounts[0]})
  })

  it('Stake - Add Stake', async () => {
    let s = await stake.stake(100)
    assert.equal(s.logs[1].event, 'NotifyStaked')
  })

  it('Stake - Remove Stake', async () => {
    let s = await stake.unStake(100)
    assert.equal(s.logs[1].event, 'NotifyStaked')
  })
})
