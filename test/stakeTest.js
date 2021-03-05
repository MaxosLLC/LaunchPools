const { expectRevert, time } = require('@openzeppelin/test-helpers');
const Stake = artifacts.require('Stake');
const ERC20 = artifacts.require('ERC20');

contract('LaunchStake', (accounts) => {
    let launchPoolStake;
    let erc20;
    const [stakeholder1, stakeholder2, stakeholder3] = [accounts[1], accounts[2], accounts[3]];
  
    before(async () => {
        erc20 = await ERC20.deployed();
        launchPoolStake = await Stake.deployed();
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
        await expectRevert(
            launchPoolStake.stake(2000, {from: stakeholder1}),
            "Stakeholder must be registered"
        );
    });

    it('Should register a stakeholder properly', async () => {
        await erc20.approve(launchPoolStake.address, 1200, {from: stakeholder1});
        await launchPoolStake.registerAndStake(1200, '0x0000000000000000000000000000000000000000', {from: stakeholder1});
        await erc20.approve(launchPoolStake.address, 2000, {from: stakeholder2});
        await launchPoolStake.registerAndStake(2000, stakeholder1, {from: stakeholder2});
        const status1 = await launchPoolStake.registered(stakeholder1);
        const status2 = await launchPoolStake.registered(stakeholder2);
        const referralCount1 = await launchPoolStake.referralCount(stakeholder1);
        const referralCount3 = await launchPoolStake.referralCount(stakeholder3);
        const referralBonus1 = await launchPoolStake.referralRewards(stakeholder1);
        const referralBonus3 = await launchPoolStake.referralRewards(stakeholder3);
        const stakes1 = await launchPoolStake.stakes(stakeholder1);
        const stakes2 = await launchPoolStake.stakes(stakeholder2);
        const totalStaked = await launchPoolStake.totalStaked();
        assert.equal(status1, true);
        assert.equal(status2, true);
        assert.equal(referralCount1.toNumber(), 1);
        assert.equal(referralCount3.toNumber(), 0);
        assert.equal(referralBonus1.toNumber(), 36);
        assert.equal(referralBonus3.toNumber(), 0);
        assert.equal(stakes1.toNumber(), 980);
        assert.equal(stakes2.toNumber(), 1764);
        assert.equal(totalStaked.toNumber(), 2744);
        
    });
    
    it('Should NOT create registration twice', async () => {
        await expectRevert(
            launchPoolStake.registerAndStake(2000, stakeholder3, {from: stakeholder1}),
            "Stakeholder is already registered"
        );

        await expectRevert(
            launchPoolStake.registerAndStake(2000, stakeholder3, {from: stakeholder2}),
            "Stakeholder is already registered"
        );
    });

    it('Should NOT create a stake if amount is below the minimum staking value', async () => {
        await expectRevert(
            launchPoolStake.stake(200, {from: stakeholder1}),
            "Amount is below minimum stake value."
        );
    });

    it('Should NOT create a stake if amount is higher than stakeholder token balance', async () => {
        await expectRevert(
            launchPoolStake.stake(20000, {from: stakeholder1}),
            "Must have enough balance to stake"
        );
    });

    it('Should calculate earnings properly', async () => {
        await time.increase(604800);
        const reward1 = await launchPoolStake.calculateEarnings(stakeholder1);
        const reward2 = await launchPoolStake.calculateEarnings(stakeholder2);
        assert.equal(reward1.toNumber(), 27);
        assert.equal(reward2.toNumber(), 49);
    });

    it('Should create a stake properly', async () => {
        await erc20.approve(launchPoolStake.address, 1000, {from: stakeholder1});
        await launchPoolStake.stake(1000, {from: stakeholder1});
        const stakes = await launchPoolStake.stakes(stakeholder1);
        const stakeRewards = await launchPoolStake.stakeRewards(stakeholder1);
        const totalStaked = await launchPoolStake.totalStaked();
        assert.equal(stakes.toNumber(), 1960);
        assert.equal(stakeRewards.toNumber(), 27);
        assert.equal(totalStaked.toNumber(), 3724);
    });

    it('Should NOT ustake if not registered', async () => {
        await expectRevert(
            launchPoolStake.unstake(200, {from: stakeholder3}),
            "Stakeholder must be registered"
        );
    });

    it('Should NOT unstake above stake balance', async () => {
        await time.increase(604800);
        await expectRevert(
            launchPoolStake.unstake(1961, {from: stakeholder1}),
            "Insufficient balance to unstake"
        );
    });

    it('Should unstake properly', async () => {
        await time.increase(604800);
        await launchPoolStake.unstake(980, {from: stakeholder1});
        const stakes = await launchPoolStake.stakes(stakeholder1);
        const stakeRewards = await launchPoolStake.stakeRewards(stakeholder1);
        const referralRewards = await launchPoolStake.referralRewards(stakeholder1);
        const referralCount = await launchPoolStake.referralCount(stakeholder1);
        const totalStaked = await launchPoolStake.totalStaked();
        const balance = await erc20.balanceOf(stakeholder1);
        assert.equal(stakes.toNumber(), 980);
        assert.equal(stakeRewards.toNumber(), 136);
        assert.equal(referralRewards.toNumber(), 36);
        assert.equal(referralCount.toNumber(), 1);
        assert.equal(totalStaked.toNumber(), 2744);
        assert.equal(balance.toNumber(), 8741);
    });

    it('Should deregister stakeholder who unstakes total stakes', async () => {
        await time.increase(604800);
        await launchPoolStake.unstake(980, {from: stakeholder1});
        const stakes = await launchPoolStake.stakes(stakeholder1);
        const referralRewards = await launchPoolStake.referralRewards(stakeholder1);
        const referralCount = await launchPoolStake.referralCount(stakeholder1);
        const totalStaked = await launchPoolStake.totalStaked();
        const status = await launchPoolStake.registered(stakeholder1);
        
        assert.equal(status, false);
        assert.equal(stakes.toNumber(), 0);
        assert.equal(referralRewards.toNumber(), 36);
        assert.equal(referralCount.toNumber(), 1);
        assert.equal(totalStaked.toNumber(), 1764);    
    });

    it('Should NOT withdraw for non-registered users', async () => {
        await expectRevert(
            launchPoolStake.withdrawEarnings({from: stakeholder3}),
            "No reward to withdraw"
        );
    });

    it('Should withdraw properly', async () => {
        await time.increase(690200);
        await launchPoolStake.withdrawEarnings({from: stakeholder2});
        const stakeRewards = await launchPoolStake.stakeRewards(stakeholder2);
        const referralRewards = await launchPoolStake.referralRewards(stakeholder2);
        const referralCount = await launchPoolStake.referralCount(stakeholder2);
        const balance = await erc20.balanceOf(stakeholder2)
        assert.equal(stakeRewards.toNumber(), 0);
        assert.equal(referralRewards.toNumber(), 0);
        assert.equal(referralCount.toNumber(), 0);
        assert.equal(balance.toNumber(), 8246);

       await time.increase(89400);
        const reward = await launchPoolStake.calculateEarnings(stakeholder2);
        assert.equal(reward.toNumber(), 14);
    });

    it('Should set staking tax properly', async () => {
        await launchPoolStake.setStakingTaxRate(3);
        const stakingTaxRate = await launchPoolStake.stakingTaxRate();
        assert.equal(stakingTaxRate.toNumber(), 3); 
    });

    it('Should set unstaking tax properly', async () => {
        await launchPoolStake.setUnstakingTaxRate(5);
        const unstakingTaxRate = await launchPoolStake.unstakingTaxRate();
        assert.equal(unstakingTaxRate.toNumber(), 5); 
    });

    it('Should set daily ROI properly', async () => {
        await launchPoolStake.setDailyROI(0);
        const dailyROI = await launchPoolStake.dailyROI();
        assert.equal(dailyROI.toNumber(), 0);  
    });

    it('Should set registration tax properly', async () => {
        await launchPoolStake.setRegistrationTax(500);
        const registrationTax = await launchPoolStake.registrationTax();
        assert.equal(registrationTax.toNumber(), 500); 
    });

    it('Should set minimum stake value properly', async () => {
        await launchPoolStake.setMinimumStakeValue(1500);
        const minimumStakeValue = await launchPoolStake.minimumStakeValue();
        assert.equal(minimumStakeValue.toNumber(), 1500); 
    });

    it('Should withdraw funds from owner properly', async () => {
        await launchPoolStake.filter(330);
        const balance = await erc20.balanceOf(accounts[0]);
        assert.equal(balance.toNumber(), 299969330); 
    });

    it('Should pause contract properly', async () => {
        const status = await launchPoolStake.active();
        await launchPoolStake.changeActiveStatus();
        const status1 = await launchPoolStake.active();
        assert.equal(status, true);
        assert.equal(status1, false); 
    });

    it('Should NOT register and stake when paused', async () => {
        await erc20.approve(launchPoolStake.address, 1200, {from: stakeholder3});
        await erc20.approve(launchPoolStake.address, 1200, {from: stakeholder2});
        await expectRevert(
            launchPoolStake.registerAndStake(1200, '0x0000000000000000000000000000000000000000', {from: stakeholder3}),
            "Smart contract is curently inactive"
        );

        await expectRevert(
            launchPoolStake.stake(1200, {from: stakeholder2}),
            "Smart contract is curently inactive"
        );
        
    });

}); 