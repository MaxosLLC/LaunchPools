const { expect } = require("chai");
const { ethers } = require("hardhat");

async function _deployStakeVault() {
    const StakeVault = await ethers.getContractFactory("StakeVault");
    return await StakeVault.deploy();
}

async function _addPool(launchPoolTracker) {
  await launchPoolTracker.addPool(
    "testpool1",
    86400,
    3600,
    10,
    10000,
  );

  return await launchPoolTracker.poolIds(0);
}

async function _mintTokensAndApprove(token, account, amount) {
  await token.mint(account.address, amount);
  await token.connect(account).approve(stakeVault.address, amount);
}

describe("Staking in LaunchPoolTracker", function() {
  const initialAmount = 100;
  let owner, acc1, acc2, token1, token2, token3, stakeVault, launchPoolTracker, firstPoolId;

  beforeEach("create and deploy contracts", async () => {
    [ owner, acc1, acc2 ] = await ethers.getSigners();

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
      [token1.address, token2.address, token3.address],
      stakeVault.address
    );

    await token1.approve(stakeVault.address, 100);
    await token2.approve(stakeVault.address, 100);
    await token3.approve(stakeVault.address, 100);
  });

  it("Add pool is working", async function() {   
    expect(await _addPool(launchPoolTracker)).to.equal(1);   
  })

  it("View pool is working", async function() {
    await _addPool(launchPoolTracker);
    await _addPool(launchPoolTracker);

    const poolIds = await launchPoolTracker.getPoolIds();
    expect(poolIds.length).to.equal(2);

    const poolId = await launchPoolTracker.poolIds(1);
    const launchPool = await launchPoolTracker.poolsById(poolId);
    const name = await launchPool.name;
    expect(name).to.equal("testpool1");
    const status = await launchPool.status;
    expect(status).to.equal(0);
    const poolValidDuration = await launchPool.poolExpiry.duration;
    expect(poolValidDuration).to.equal(86400);
    const offerValidDuration = await launchPool.offerExpiry.duration;
    expect(offerValidDuration).to.equal(3600);
    const minOffer = await launchPool.offer.bounds.minimum;
    expect(minOffer).to.equal(10);
    const maxOffer = await launchPool.offer.bounds.maximum;
    expect(maxOffer).to.equal(10000);
  })
  async function _mintTokensAndApprove(token, account, amount) {
    await token.mint(account.address, amount);
    await token.connect(account).approve(stakeVault.address, amount);
  }

  it("Offer new, cancel routine is working.", async function() {   
    await launchPoolTracker.addPool(
        "testpool1",
        86400,
        3600,
        10,
        10000,
    );
    const poolId = await launchPoolTracker.poolIds(0);
    await launchPoolTracker.newOffer(poolId, "https://example.com", 3000);
    let launchPool = await launchPoolTracker.poolsById(poolId);
    let status = launchPool.status;
    expect(status).to.equal(1);
    const url = launchPool.offer.url;
    expect(url).to.equal("https://example.com");
    const duration = launchPool.offerExpiry.duration;
    expect(duration).to.equal(3000);

    await launchPoolTracker.cancelOffer(poolId);
    launchPool = await launchPoolTracker.poolsById(poolId);
    status = launchPool.status;
    expect(status).to.equal(0);
  });

  it("Offer end routine is working.", async function() {   
    await launchPoolTracker.addPool(
        "testpool1",
        86400,
        3600,
        10,
        10000,
    );
    const poolId = await launchPoolTracker.poolIds(0);
    await launchPoolTracker.newOffer(poolId, "https://example.com", 3000);

    await launchPoolTracker.endOffer(poolId);
    const launchPool = await launchPoolTracker.poolsById(poolId);
    const status = launchPool.status;
    expect(status).to.equal(0);
  });

});
