const { expect } = require("chai");
const { ethers } = require("hardhat");

async function _mintTokensAndApprove(stakeVault, token, account, amount) {
  await token.mint(account.address, amount);
  await token.connect(account).approve(stakeVault.address, amount);
}

describe("Test stake vault", function() {
  let admin, sponsor, staker, usdc, stakeVault, launchPoolTracker;
  const initialAmount = 300;

  beforeEach("Scenario to test the stakeVault", async () => {
    [ admin, sponsor, staker ] = await ethers.getSigners();

    MockERC20 = await ethers.getContractFactory("MockERC20");
    usdc = await MockERC20.deploy(initialAmount);

    const StakeVault = await ethers.getContractFactory("StakeVault");
    stakeVault = await StakeVault.deploy();
    await stakeVault.deployed();

    const LaunchPoolTracker = await ethers.getContractFactory("LaunchPoolTracker");
    launchPoolTracker = await LaunchPoolTracker.deploy(
      [usdc.address],
      stakeVault.address
    );

    await usdc.approve(stakeVault.address, initialAmount);

    await _mintTokensAndApprove(stakeVault, usdc, sponsor, initialAmount);

    await launchPoolTracker.deployed();

    // As Sponsor: Create a pool. The minimum amount should be $100. The maximum amount should be $1000
    await launchPoolTracker.addPool(
      "testpool1",
      86400,
      3600,
      100,
      1000
    );

    stakeVault.setPoolContract(launchPoolTracker.address);
  });

  it("Scenario to test the stakeVault", async function(){
    poolId = await launchPoolTracker.poolIds(0);

    // As Sponsor: Add an offer to the pool and put the pool into committing state.
    await launchPoolTracker.newOffer(poolId, 'https://maxos.com', 1000)
    launchPool = await launchPoolTracker.poolsById(poolId);
    expect(launchPool.status).to.equal(1);

    // As Investor: Add three stakes. All of them will be USDC. STAKE 1 - $50 . Stake 2 - $75 . Stake 3 - $50
    await stakeVault.addStake(poolId, usdc.address, 50);
    await stakeVault.addStake(poolId, usdc.address, 75);
    await stakeVault.addStake(poolId, usdc.address, 50);

    const stakes = await launchPoolTracker.getStakes(poolId);
    expect(stakes.length).to.equal(3);

    // As Investor: Commit stakes 2 and 3    
    await stakeVault.commitStake(stakes[1]);
    await stakeVault.commitStake(stakes[2]);

    // As Admin: Set the expiration time on the offer to "Now". THIS WILL REQUIRE CHANGES TO THE LAUNCHPOOL CODE


  });
});
