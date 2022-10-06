import chai from "chai";
import { ethers } from "hardhat";
import { solidity } from 'ethereum-waffle';
import { ContractFactory, BigNumber } from "ethers";
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { TestToken, StakeVault } from '../types';

chai.use(solidity);
const { expect } = chai;

describe("2. Stake Test", () => {
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
    stakeVault  = await stakeVaultFactory.deploy(testToken.address) as StakeVault;

    // Set default allowed token for using in the deal.
    await stakeVault.addAllowedToken(testToken.address);

    //Transfer tokens to the investors
    await testToken.transfer(investorA.address, 200000);
    await testToken.transfer(investorB.address, 200000);
    await testToken.transfer(investorC.address, 200000);

    //Approve tokens of the investors
    await testToken.connect(investorA).approve(stakeVault.address, BigNumber.from('10').pow('18'), { from: investorA.address });
    await testToken.connect(investorB).approve(stakeVault.address, BigNumber.from('10').pow('18'), { from: investorB.address });
    await testToken.connect(investorC).approve(stakeVault.address, BigNumber.from('10').pow('18'), { from: investorC.address });
  });

  describe("Deploying Contracts",() => {
    it('Should have been deployed correctly', async () => {
      expect(await stakeVault.owner()).to.equal(owner.address);
      expect(await testToken.balanceOf(investorA.address)).to.equal(200000);
      expect(await testToken.balanceOf(investorB.address)).to.equal(200000);
      expect(await testToken.balanceOf(investorC.address)).to.equal(200000);
    });
  });

  describe("Test stakes event in a deal", async () => {
    beforeEach('Add a deal', async () => {
      await stakeVault.connect(sponsor).addDeal(
        'Test Deal', // deal name
        'https://test.com', // deal url
        investorA.address, // lead investor
        100, // start bonus
        0, // end bonus
        10000, // presale amount
        1000, // minimum sale amount
        50000, // maximum sale amount
        [100, 10000], // stake limit amount (min, max)
        604800, // offer period
        testToken.address // staking token address
      );
    });

    it('The investors stake on a deal', async () => {
      // Check a deal when other investor stake, not a lead investor
      await expect(stakeVault.connect(investorB).deposit(1, 1000)).to.be.revertedWith("Can't Stake.");

      await stakeVault.connect(investorA).deposit(1, 1000); // lead investor stake at first.
      await stakeVault.connect(investorB).deposit(1, 2000); // Other one can stake.

      expect(await stakeVault.checkDealStatus(1, 1)).to.equal(true); // The deal status should be Staking after stake.
    });

    it('Test stake limit', async () => {
      await expect(stakeVault.connect(investorB).deposit(1, 10)).to.be.revertedWith("Wrong Amount.");
      await expect(stakeVault.connect(investorB).deposit(1, 50000)).to.be.revertedWith("Wrong Amount.");
    });

    it('The investors unstake staked amount', async () => {
      // The investors stake their assets
      await stakeVault.connect(investorA).deposit(1, 1000);
      await stakeVault.connect(investorB).deposit(1, 2500);

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
    
    it('The investors unstake over stakes than max sale', async () => {
      await stakeVault.connect(sponsor).updateDeal(
        1, 
        'https://test.com',
        investorA.address,
        100,
        0,
        10000,
        1000,
        50000,
        [100, 0]
      );
      // The investors stake their assets
      await stakeVault.connect(investorA).deposit(1, 10000);
      await stakeVault.connect(investorB).deposit(1, 60000);
      await stakeVault.connect(investorA).deposit(1, 20000);

      // Update deal status
      await stakeVault.connect(owner).updateDealStatus(1, 2);
      await stakeVault.connect(owner).updateDealStatus(1, 3);

      await expect(stakeVault.connect(investorA).withdrawOverAmount(1)).to.be.revertedWith("Error.");

      // InvestrB unstake the over stakes
      await stakeVault.connect(investorB).withdrawOverAmount(2)
      await stakeVault.connect(investorA).withdrawOverAmount(3)

      const deal = await stakeVault.connect(sponsor).dealInfo(1);
      expect(deal.totalStaked).to.eq(50000);
    });

    it('Only the owner or sponsor should use sendBack.', async () => {
      // The investors stake their assets
      await stakeVault.connect(investorA).deposit(1, 1000);
      await stakeVault.connect(investorB).deposit(1, 2500);
      
      // Checking current staked amount
      const A_Stake  = await stakeVault.stakeInfo(1);
      const B_Stake  = await stakeVault.stakeInfo(2);
      expect(A_Stake.amount).to.eq(1000);
      expect(B_Stake.amount).to.eq(2500);

      // Close the deal
      await stakeVault.connect(owner).updateDealStatus(1, 5);

      // SendBack the staked amount by owner and sponsor of a deal
      await stakeVault.connect(owner).sendBack(1);
      await stakeVault.connect(sponsor).sendBack(2);
      
      // The sender should be a owner or sponsor and the stakted amount is over 0 when unstaking 
      await expect(stakeVault.connect(investorA).sendBack(1)).to.be.revertedWith("No Permission.");
      
      // Checking current amount
      const A_UnStake  = await stakeVault.stakeInfo(1);
      const B_UnStake  = await stakeVault.stakeInfo(2);
      expect(A_UnStake.amount).to.eq(0);
      expect(B_UnStake.amount).to.eq(0);
    });

    it('Should claim staked amount after setting deal status as a Claiming by owner', async () => {
      // The investors stake their assets
      await stakeVault.connect(investorA).deposit(1, 1500);
      await stakeVault.connect(investorB).deposit(1, 2500);
      
      // Check current staked amount
      const A_Stake  = await stakeVault.stakeInfo(1);
      const B_Stake  = await stakeVault.stakeInfo(2);
      expect(A_Stake.amount).to.eq(1500);
      expect(B_Stake.amount).to.eq(2500);

      // Update deal status
      await stakeVault.connect(owner).updateDealStatus(1, 2);
      await stakeVault.connect(owner).updateDealStatus(1, 3);

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
