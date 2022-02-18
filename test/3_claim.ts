import chai from "chai";
import { ethers } from "hardhat";
import { solidity } from 'ethereum-waffle';
import { ContractFactory, BigNumber } from "ethers";
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { TestToken, StakeVault } from '../types';

chai.use(solidity);
const { expect } = chai;
const offerPeriod = 604800;

describe("3. Claim Test", () => {
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

  describe("Test claim in a deal",() => {
    it('Should have been deployed correctly', async () => {
      expect(await stakeVault.owner()).to.equal(owner.address);
      expect(await stakeVault.isAllowedToken(testToken.address)).to.equal(true);
      expect(await testToken.balanceOf(investorA.address)).to.equal(20000);
      expect(await testToken.balanceOf(investorB.address)).to.equal(20000);
      expect(await testToken.balanceOf(investorC.address)).to.equal(20000);
    });
  });

  describe("Test claim event in a deal", async () => {
    beforeEach('Add a deal', async () => {
      await stakeVault.connect(sponsor).addDeal(
        'Test Deal', // deal name
        'https://google.com', // deal url
        investorA.address, // lead investor
        100, // start bonus
        0, // end bonus
        10000, // presale amount
        1000, // minimum sale amount
        100000, // maximum sale amount
        testToken.address // staking token address
      );
    });

    it('Should claim staked amount after setting deal status as a Claiming by owner', async () => {
      // The investors stake their assets
      await stakeVault.connect(investorA).deposite(1, 1500);
      await stakeVault.connect(investorB).deposite(1, 2500);
      
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
