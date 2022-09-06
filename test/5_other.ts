import chai from "chai";
import { ethers } from "hardhat";
import { solidity } from 'ethereum-waffle';
import { ContractFactory, BigNumber } from "ethers";
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { TestToken, StakeVault } from '../types';

chai.use(solidity);
const { expect } = chai;

describe("5. Other Test", () => {
  let testToken: TestToken;
  let stakeVault: StakeVault;
  let stakeVaultFactory: ContractFactory;
  let testTokenFactory: ContractFactory;
  let owner: SignerWithAddress;
  let sponsor: SignerWithAddress;
  let investorA: SignerWithAddress;

  beforeEach("Contracts initial setup", async () => {
    [ owner, sponsor, investorA ] = await ethers.getSigners();
    testTokenFactory  = await ethers.getContractFactory("TestToken"); 
    stakeVaultFactory = await ethers.getContractFactory("StakeVault"); 
    testToken   = await testTokenFactory.deploy() as TestToken;
    stakeVault  = await stakeVaultFactory.deploy(testToken.address) as StakeVault;

    // Set default allowed token for using in the deal.
    await stakeVault.addAllowedToken(testToken.address);

    //Transfer tokens to the investors
    await testToken.transfer(investorA.address, 20000);

    //Approve tokens of the investors
    await testToken.connect(investorA).approve(stakeVault.address, BigNumber.from('10').pow('18'), { from: investorA.address });
  });

  describe("Deploying Contracts",() => {
    it('Should have been deployed correctly', async () => {
      expect(await stakeVault.owner()).to.equal(owner.address);
      expect(await stakeVault.allowedTokenList(testToken.address)).to.equal(true);
      expect(await testToken.balanceOf(investorA.address)).to.equal(20000);
    });
  });

  describe("Test rest parts", async () => {
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
        604800, // offer period
        testToken.address // staking token address
      );
    });

    it('Check getting deal ids', async () => {
      await stakeVault.connect(sponsor).addDeal(
        'Second Deal',
        'https://test.com',
        investorA.address,
        100,
        0,
        10000,
        1000,
        100000,
        604800, // offer period
        testToken.address
      );
      await stakeVault.connect(sponsor).addDeal(
        'Third Deal',
        'https://test.com',
        investorA.address,
        100,
        0,
        10000,
        1000,
        100000,
        604800, // offer period
        testToken.address
      );

      await stakeVault.connect(investorA).deposit(1, 1500);
      let dealIds = await stakeVault.getDealIds(0, 0);  // Get All Deal Ids
      expect(dealIds.length).to.eq(3);
      dealIds = await stakeVault.getDealIds(1, 0); // Get Deal Ids that has not NotDisplaying & Closed status
      expect(dealIds.length).to.eq(1);
      dealIds = await stakeVault.getDealIds(2, 0); // Get Deal Ids that has NotDisplaying status
      expect(dealIds.length).to.eq(2);
      dealIds = await stakeVault.getDealIds(2, 1); // Get Deal Ids that has Staking status
      expect(dealIds.length).to.eq(1);
    })
  });
});
