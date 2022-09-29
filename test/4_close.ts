import chai from "chai";
import { ethers } from "hardhat";
import { solidity } from 'ethereum-waffle';
import { ContractFactory, BigNumber } from "ethers";
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { TestToken, StakeVault } from '../types';

chai.use(solidity);
const { expect } = chai;

describe("4. Close Test", () => {
  let testToken: TestToken;
  let stakeVault: StakeVault;
  let stakeVaultFactory: ContractFactory;
  let testTokenFactory: ContractFactory;
  let owner: SignerWithAddress;
  let sponsor: SignerWithAddress;
  let investorA: SignerWithAddress;

  beforeEach("Contracts initial setup", async () => {
    [owner, sponsor, investorA] = await ethers.getSigners();
    testTokenFactory = await ethers.getContractFactory("TestToken");
    stakeVaultFactory = await ethers.getContractFactory("StakeVault");
    testToken = await testTokenFactory.deploy() as TestToken;
    stakeVault = await stakeVaultFactory.deploy(testToken.address) as StakeVault;

    // Set default allowed token for using in the deal.
    await stakeVault.addAllowedToken(testToken.address);

    //Transfer tokens to the investors
    await testToken.transfer(investorA.address, 20000);

    //Approve tokens of the investors
    await testToken.connect(investorA).approve(stakeVault.address, BigNumber.from('10').pow('18'), { from: investorA.address });
  });

  describe("Deploying Contracts", () => {
    it('Should have been deployed correctly', async () => {
      expect(await stakeVault.owner()).to.equal(owner.address);
      expect(await stakeVault.allowedTokenList(testToken.address)).to.equal(true);
      expect(await testToken.balanceOf(investorA.address)).to.equal(20000);
    });
  });

  describe("Testing all functions when closeAll is true.", async () => {
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

    it('Check deal.', async () => {
      // Set CloseAll is true
      await stakeVault.connect(owner).toggleClose();

      // Check add a deal
      await expect(
        stakeVault.connect(sponsor).addDeal(
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
        )
      ).to.be.revertedWith("Closed.");

      // Check update a deal
      await expect(
        stakeVault.connect(sponsor).updateDeal(
          1, // deal Id
          'https://test.com', // deal url
          investorA.address, // lead investor
          50, // start bonus
          20, // end bonus
          10000, // presale amount
          1000, // minimum sale amount
          100000, // maximum sale amount
          [0, 10000] // stake limit amount (min, max)
        )
      ).to.be.revertedWith("Closed.");
    });

    it('Check stake.', async () => {
      stakeVault.connect(investorA).deposit(1, 1000);

      // Set CloseAll is true
      await stakeVault.connect(owner).toggleClose();

      // Check deposit
      await expect(
        stakeVault.connect(investorA).deposit(1, 1500)
      ).to.be.revertedWith("Closed.");

      // Check withdraw
      await stakeVault.connect(investorA).withdraw(1);
    });

    it('Check claim.', async () => {
      stakeVault.connect(investorA).deposit(1, 1000);

      // Update deal status
      await stakeVault.connect(owner).updateDealStatus(1, 2);
      await stakeVault.connect(owner).updateDealStatus(1, 3);
      await stakeVault.connect(owner).updateDealStatus(1, 4);

      // Set CloseAll is true
      await stakeVault.connect(owner).toggleClose();

      // Check claim
      await expect(
        stakeVault.connect(sponsor).claim(1)
      ).to.be.revertedWith("Closed.");
      
      // Check withdraw
      await stakeVault.connect(investorA).withdraw(1);
      
      // SendBack the staked amount by owner and sponsor of a deal
      await stakeVault.connect(owner).sendBack(1);
      await stakeVault.connect(sponsor).sendBack(1);
    });
  });
});
