const { expectRevert, time } = require('@openzeppelin/test-helpers');
const LaunchStake = artifacts.require('LaunchStake');
const ERC20 = artifacts.require('ERC20');

contract('LaunchStake', (accounts) => {
    let launchPoolStake;
    let erc20;
    const [stakeholder1, stakeholder2, stakeholder3] = [accounts[1], accounts[2], accounts[3]];
  
    before(async () => {
        erc20 = await ERC20.deployed();
        launchPoolStake = await LaunchStake.deployed();
        await erc20.transfer(launchPoolStake.address, 1000);
        await erc20.approve(launchPoolStake.address, 100000000);
        await erc20.transfer(stakeholder1, 10000);
        await erc20.transfer(stakeholder2, 10000);
        await erc20.transfer(stakeholder3, 10000);
    });

    it('Should transfer a balance of 1000 tokens to smart contract properly', async () => {
        const balance = await erc20.balanceOf(launchPoolStake.address);
        assert.equal(balance, 1000);
    });

    it('Should NOT create a stake without registration', async () => {
        await expectRevert(launchPoolStake.stake(2000), "Stakeholder must be registered");
    });

    it('Should NOT create a stake if amount is below the minimum staking value', async () => {
        await expectRevert(launchPoolStake.stake(200), "Amount is below minimum stake value.");
    });

    it('Should NOT create a stake if amount is higher than stakeholder token balance', async () => {
        await expectRevert(launchPoolStake.stake(20000), "Must have enough balance to stake");
    });

    it('Should NOT withdraw for non-registered users', async () => {
        await expectRevert(launchPoolStake.withdraw(300), "No reward to withdraw");
    });

    it('Should NOT register and stake when paused', async () => {
        await erc20.approve(launchPoolStake.address, 1200, {from: stakeholder3});
        await erc20.approve(launchPoolStake.address, 1200, {from: stakeholder2});
        await expectRevert(launchPoolStake.stake(1200), "Smart contract is curently inactive");

        await expectRevert(launchPoolStake.stake(1200), "Smart contract is curently inactive");
        
    });

}); 