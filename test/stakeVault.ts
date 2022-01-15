import chai from "chai";
import { ethers } from "hardhat";
import { solidity } from 'ethereum-waffle';
import { ContractFactory, BigNumber } from "ethers";
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { TestToken, StakeVault } from '../types';

chai.use(solidity);
const { expect } = chai;
const offerPeriod = 604800;

describe("StakeVault Contract", () => {
  let testToken: TestToken;
  let stakeVault: StakeVault;
  let stakeVaultFactory: ContractFactory;
  let testTokenFactory: ContractFactory;
  let owner: SignerWithAddress;
  let sponsor: SignerWithAddress;
  let investorA: SignerWithAddress;
  let investorB: SignerWithAddress;
  let investorC: SignerWithAddress;

  beforeEach("Contracts initial setup", async () => {
    [ owner, sponsor, investorA, investorB, investorC ] = await ethers.getSigners();
    testTokenFactory  = await ethers.getContractFactory("TestToken"); 
    stakeVaultFactory = await ethers.getContractFactory("StakeVault"); 
    testToken   = await testTokenFactory.deploy() as TestToken;
    stakeVault  = await stakeVaultFactory.deploy(testToken.address, offerPeriod) as StakeVault;

    // Set default allowed token for using in the deal.
    await stakeVault.addAllowedToken(testToken.address);

    //Transfer tokens to the investors
    await testToken.transfer(investorA.address, 20000);
    await testToken.transfer(investorB.address, 20000);
    await testToken.transfer(investorC.address, 20000);

    //Approve tokens of the investors
    await testToken.connect(investorA).approve(stakeVault.address, BigNumber.from('10').pow('18'), { from: investorA.address });
    await testToken.connect(investorB).approve(stakeVault.address, BigNumber.from('10').pow('18'), { from: investorB.address });
    await testToken.connect(investorC).approve(stakeVault.address, BigNumber.from('10').pow('18'), { from: investorC.address });
  });

  describe("Deploying Contracts",() => {
    it('Should have been deployed correctly', async () => {
      expect(await stakeVault.owner()).to.equal(owner.address);
      expect(await stakeVault.isAllowedToken(testToken.address)).to.equal(true);
      expect(await testToken.balanceOf(investorA.address)).to.equal(20000);
      expect(await testToken.balanceOf(investorB.address)).to.equal(20000);
      expect(await testToken.balanceOf(investorC.address)).to.equal(20000);
    });
  });

  describe("Testing StakeVault Contract", async () => {
    beforeEach('Add a deal', async () => {
      await stakeVault.connect(sponsor).addDeal(
        'Test Deal',
        'https://google.com',
        100,
        0,
        10000,
        1000,
        100000,
        0,
        testToken.address
      );
    });

    it('The status of deal should be a Staking after creating new deal', async () => {
      expect(await stakeVault.checkDealStatus(1, 1)).to.equal(true);
    });

    it('Set price to the deal', async () => {
      await stakeVault.connect(sponsor).setDealPrice(1, 100);

      // The deal status should be Offering after setting price
      expect(await stakeVault.checkDealStatus(1, 2)).to.equal(true);

      // Checking the price of deal
      const deal = await stakeVault.dealInfo(1);
      expect(BigNumber.from(deal.dealPrice.price).toNumber()).to.eq(100);
    });

    it('Check bonus of investors after staked', async () => {
      // The investors stake their assests
      await stakeVault.connect(investorA).deposite(1, 1000);
      await stakeVault.connect(investorB).deposite(1, 2500);
      await stakeVault.connect(investorC).deposite(1, 5000);
      await stakeVault.connect(investorA).deposite(1, 500);
      
      // Getting the bonus from staked amount
      const A_Bonus1  = await stakeVault.getBonus(1);
      const A_Bonus2  = await stakeVault.getBonus(4);
      const B_Bonus   = await stakeVault.getBonus(2);
      const C_Bonus   = await stakeVault.getBonus(3);
      
      // Checking the bonus
      expect(A_Bonus1).to.equal(BigNumber.from('95'));
      expect(A_Bonus2).to.equal(BigNumber.from('12'));
      expect(B_Bonus).to.equal(BigNumber.from('77'));
      expect(C_Bonus).to.equal(BigNumber.from('40'));
    });

    it('Unstake investors staked amount', async () => {
      // The investors stake their assets
      await stakeVault.connect(investorA).deposite(1, 1000);
      await stakeVault.connect(investorB).deposite(1, 2500);

      // Checking the staked amount
      const A_Stake  = await stakeVault.stakeInfo(1);
      const B_Stake  = await stakeVault.stakeInfo(2);
      expect(A_Stake.amount).to.eq(1000);
      expect(B_Stake.amount).to.eq(2500);
      
      // The investors unstake their assets
      await stakeVault.connect(investorA).withdraw(1);
      await stakeVault.connect(investorB).withdraw(2);

      // Checking the amount after unstaking
      const A_UnStake  = await stakeVault.stakeInfo(1);
      const B_UnStake  = await stakeVault.stakeInfo(2);
      expect(A_UnStake.amount).to.eq(0);
      expect(B_UnStake.amount).to.eq(0);
    });

    it('Only the owner or sponsor should use sendBack.', async () => {
      // The investors stake their assets
      await stakeVault.connect(investorA).deposite(1, 1000);
      await stakeVault.connect(investorB).deposite(1, 2500);
      
      // Checking current staked amount
      const A_Stake  = await stakeVault.stakeInfo(1);
      const B_Stake  = await stakeVault.stakeInfo(2);
      expect(A_Stake.amount).to.eq(1000);
      expect(B_Stake.amount).to.eq(2500);

      // SendBack the staked amount by owner and sponsor of a deal
      await stakeVault.connect(owner).sendBack(1);
      await stakeVault.connect(sponsor).sendBack(2);
      
      // The sender should be a owner or sponsor and the stakted amount is over 0 when unstaking 
      await expect(stakeVault.connect(investorA).sendBack(1)).to.be.revertedWith("You have no permission to send back the staked amount.");
      await expect(stakeVault.connect(owner).sendBack(1)).to.be.revertedWith("The withdraw amount is not enough.");
      
      // Checking current amount
      const A_UnStake  = await stakeVault.stakeInfo(1);
      const B_UnStake  = await stakeVault.stakeInfo(2);
      expect(A_UnStake.amount).to.eq(0);
      expect(B_UnStake.amount).to.eq(0);
    });

    it('Should claim staked amount after setting deal status as a Claiming by owner', async () => {
      // The investors stake their assets
      await stakeVault.connect(investorA).deposite(1, 1000);
      await stakeVault.connect(investorB).deposite(1, 2500);
      
      // Check current staked amount
      const A_Stake  = await stakeVault.stakeInfo(1);
      const B_Stake  = await stakeVault.stakeInfo(2);
      expect(A_Stake.amount).to.eq(1000);
      expect(B_Stake.amount).to.eq(2500);

      // Owner set deal status as Claiming
      await stakeVault.connect(owner).updateDealStatus(1, 4);
      expect(await stakeVault.checkDealStatus(1, 4)).to.equal(true);

      // The sponsor claim the staked amount from the deal
      await stakeVault.connect(sponsor).claim(1);

      // Checking balance after claiming
      const A_Balance  = await stakeVault.stakeInfo(1);
      const B_Balance  = await stakeVault.stakeInfo(2);
      expect(A_Balance.amount).to.eq(0);
      expect(B_Balance.amount).to.eq(0);
    });
  });
});
