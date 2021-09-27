const { expect } = require("chai");
const { ethers } = require("hardhat");

async function _mintTokensAndApprove(stakeVault, token, account, amount) {
  await token.mint(account.address, amount);
  await token.connect(account).approve(stakeVault.address, amount);
}

describe("Test stake vault", function() {
  let admin, sponsor, staker, usdc, stakeVault, dealTracker;
  const initialAmount = 300;

  beforeEach("Scenario to test the stakeVault", async () => {
    [ admin, sponsor, staker ] = await ethers.getSigners();

    MockERC20 = await ethers.getContractFactory("MockERC20");
    usdc = await MockERC20.deploy(initialAmount);

    const StakeVault = await ethers.getContractFactory("StakeVault");
    stakeVault = await StakeVault.deploy();
    await stakeVault.deployed();

    const DealTracker = await ethers.getContractFactory("DealTracker");
    dealTracker = await DealTracker.deploy(
      [usdc.address],
      stakeVault.address
    );

    await usdc.approve(stakeVault.address, initialAmount);

    await _mintTokensAndApprove(stakeVault, usdc, sponsor, initialAmount);

    await dealTracker.deployed();

    // As Sponsor: Create a pool. The minimum amount should be $100. The maximum amount should be $1000
    await dealTracker.addPool(
      "testpool1",
      "www.test.com",
      86400,
      3600,
      100,
      1000
    );

    stakeVault.setPoolContract(dealTracker.address);
  });

  it("Scenario to test the stakeVault", async function(){
    poolId = await dealTracker.poolIds(0);

    // As Sponsor: Add an offer to the pool and put the pool into committing state.
    await dealTracker.newOffer(poolId, 'https://maxos.com', 1000)
    launchPool = await dealTracker.poolsById(poolId);
    expect(launchPool.status).to.equal(1);

    // As Investor: Add three stakes. All of them will be USDC. STAKE 1 - $50 . Stake 2 - $75 . Stake 3 - $50
    await stakeVault.addStake(poolId, usdc.address, 50);
    await stakeVault.addStake(poolId, usdc.address, 75);
    await stakeVault.addStake(poolId, usdc.address, 50);

    //An Investor unstake his last stake
    await stakeVault.unStake(2);
    const stakes = await launchPoolTracker.getStakes(poolId);
    expect(stakes.length).to.equal(2);

    const totalCommittedAmount = await launchPoolTracker.getTotalCommittedAmount(poolId);
    expect(totalCommittedAmount.toNumber()).to.equal(125);

    await stakeVault.setDeliveringStatus(poolId);

    // // As Admin: Set the expiration time on the offer to "Now". THIS WILL REQUIRE CHANGES TO THE LAUNCHPOOL CODE
    const canClaimOffer = await launchPoolTracker.canClaimOffer(poolId)
    expect(canClaimOffer).to.equal(true);
    await stakeVault.setPoolClaimStatus(poolId);

    //As Admin/Owner Call the function to set the pool into Claiming state
    await stakeVault.claim(poolId);

  });
});
