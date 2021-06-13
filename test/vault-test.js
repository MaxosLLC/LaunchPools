const { expect } = require("chai");
const { ethers } = require("hardhat");

async function _mintTokensAndApprove(stakeVault, token, account, amount) {
  await token.mint(account.address, amount);
  await token.connect(account).approve(stakeVault.address, amount);
}

describe("Test stake vault", function() {
  let owner, acc1, acc2, recvFunds, token1, token2, token3, token4, stakeVault, launchPoolTracker;

  const initialAmount = 100;
  const poolId1 = "00";
  const poolId2 = "01";


  beforeEach("create and deploy erc and vault with 1 pool", async () => {
    [ owner, acc1, acc2, recvFunds ] = await ethers.getSigners();

    MockERC20 = await ethers.getContractFactory("MockERC20");
    token1 = await MockERC20.deploy(initialAmount);
    token2 = await MockERC20.deploy(initialAmount);
    token3 = await MockERC20.deploy(initialAmount);
    token4 = await MockERC20.deploy(initialAmount);

    const StakeVault = await ethers.getContractFactory("StakeVault");
    stakeVault = await StakeVault.deploy();
    await stakeVault.deployed();

    const LaunchPoolTracker = await ethers.getContractFactory("LaunchPoolTracker");
    launchPoolTracker = await LaunchPoolTracker.deploy(
      [token1.address, token2.address, token3.address, token4.address],
      stakeVault.address
    );

    await token1.approve(stakeVault.address, 100);
    await token2.approve(stakeVault.address, 100);
    await token3.approve(stakeVault.address, 100);

    await _mintTokensAndApprove(stakeVault, token1, acc1, 100);
    await _mintTokensAndApprove(stakeVault, token1, acc2, 100);

    await launchPoolTracker.deployed();

    await launchPoolTracker.addPool(
      "testpool1",
      86400,
      3600,
      10,
      10000,
    );
  });

  it("Stake is working", async function(){
    poolId = await launchPoolTracker.poolIds(0);
    await stakeVault.addStake(poolId, token1.address, 1);
    const stakes = await launchPoolTracker.getStakes(poolId);
    expect(stakes.length).to.equal(1);
  });

  it("Un-Stake is working", async function(){
    poolId = await launchPoolTracker.poolIds(0);
    await stakeVault.addStake(poolId, token1.address, 1);
    const stakes = await launchPoolTracker.getStakes(poolId);
    expect(stakes.length).to.equal(1);

    await stakeVault.unStake(stakes[0]);
  });

  it("Un-Stake is not working with committed stake.", async function() {
    poolId = await launchPoolTracker.poolIds(0);
    await stakeVault.addStake(poolId, token1.address, 1);
    const stakes = await launchPoolTracker.getStakes(poolId);
    expect(stakes.length).to.equal(1);
    await stakeVault.commitStake(stakes[0]);

    await expect(stakeVault.unStake(stakes[0])).to.be.reverted;
  })


});

