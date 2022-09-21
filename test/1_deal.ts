import chai from "chai";
import { ethers } from "hardhat";
import { solidity } from 'ethereum-waffle';
import { ContractFactory, BigNumber, Signer } from "ethers";
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { TestToken, StakeVault } from '../types';

chai.use(solidity);
const { expect } = chai;

describe("1. Deal Test", () => {
  let testToken: TestToken;
  let stakeVault: StakeVault;
  let stakeVaultFactory: ContractFactory;
  let testTokenFactory: ContractFactory;
  let owner: SignerWithAddress;
  let sponsor: SignerWithAddress;
  let investorA: SignerWithAddress;
  let investorB: SignerWithAddress;

  beforeEach("Contracts initial setup", async () => {
    [ owner, sponsor, investorA, investorB ] = await ethers.getSigners();
    testTokenFactory  = await ethers.getContractFactory("TestToken"); 
    stakeVaultFactory = await ethers.getContractFactory("StakeVault"); 
    testToken   = await testTokenFactory.deploy() as TestToken;
    stakeVault  = await stakeVaultFactory.deploy(testToken.address) as StakeVault;

    // Set default allowed token for using in the deal.
    await stakeVault.addAllowedToken(testToken.address);

    //Transfer tokens to the investors
    await testToken.transfer(investorA.address, 20000);
    await testToken.transfer(investorB.address, 20000);

    //Approve tokens of the investors
    await testToken.connect(investorA).approve(stakeVault.address, BigNumber.from('10').pow('18'), { from: investorA.address });
    await testToken.connect(investorB).approve(stakeVault.address, BigNumber.from('10').pow('18'), { from: investorB.address });
  });

  describe("Deploying Contracts",() => {
    it('Should have been deployed correctly', async () => {
      expect(await stakeVault.owner()).to.equal(owner.address);
      expect(await testToken.balanceOf(investorA.address)).to.equal(20000);
      expect(await testToken.balanceOf(investorB.address)).to.equal(20000);
    });
  });

  describe("Test several status of a deal", async () => {
    beforeEach('Add a deal', async () => {
      await stakeVault.connect(sponsor).addDeal(
        'Test Deal', // deal name
        'https://test.com', // deal url
        investorA.address, // lead investor
        100, // start bonus
        0, // end bonus
        10000, // presale amount
        1000, // minimum sale amount
        100000, // maximum sale amount
        [0, 10000], // stake limit amount (min, max)
        604800, // offer period
        testToken.address // staking token address
      );
    });

    it('The status of deal should be a NotDisplaying after creating new deal', async () => {
      expect(await stakeVault.checkDealStatus(1, 0)).to.equal(true);
    });

    it('Check deal when update parameters.', async () => {
      await stakeVault.connect(sponsor).updateDeal(
        1, // deal Id
        investorB.address, // lead investor
        50, // start bonus
        20, // end bonus
        10000, // presale amount
        [0, 10000], // stake limit amount (min, max)
        testToken.address // staking token price
      );

      // Update deal after staking.
      await stakeVault.connect(investorB).deposit(1, 1000); // lead investor stake at first.
      await expect(
        stakeVault.connect(sponsor).updateDeal(
          1,
          investorA.address,
          100,
          0,
          10000,
          [0, 10000],
          testToken.address
        )
      ).to.be.revertedWith("Stake Exist.");
    });

    it('Check deal status when change lead investor.', async () => {
      expect(await stakeVault.checkDealStatus(1, 0)).to.equal(true);
      await stakeVault.connect(sponsor).updateDeal(
        1, 
        '0x0000000000000000000000000000000000000000',
        50,
        20,
        10000,
        [0, 10000],
        testToken.address
      );
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

  });
});
