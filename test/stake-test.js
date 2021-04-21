const { expect } = require("chai");
const { ethers } = require("hardhat");

const initialAmount = 100;

describe("Stake", function() {
  let owner, token1, token2, token3, token4, launchPool;

  beforeEach("create and deploy erc and stake", async () => {
    [ owner ] = await ethers.getSigners();

    MockERC20 = await ethers.getContractFactory("MockERC20");
    token1 = await MockERC20.deploy(initialAmount);
    token2 = await MockERC20.deploy(initialAmount);
    token3 = await MockERC20.deploy(initialAmount);
    token4 = await MockERC20.deploy(initialAmount);

    const LaunchPool = await ethers.getContractFactory("LaunchPool");
    launchPool = await LaunchPool.deploy(
      [token1.address, token2.address, token3.address],
      "testpool1",
      50,
      1000);

    await token1.approve(launchPool.address, 100);
    await token2.approve(launchPool.address, 100);
    await token3.approve(launchPool.address, 100);
  });

  it("Deploy with more than 3 tokens", async function() {
    const LaunchPool = await ethers.getContractFactory("LaunchPool");
    await expect(
      LaunchPool.deploy(
        [token1.address, token2.address, token3.address, token4.address],
        "testpool1", 50, 1000)
    ).to.be.reverted;
  });

  it("Owner's amount is initially zero with all tokens", async function() {
    let ownerStakedAmount = await launchPool.stakesOf(owner.address, token1.address);
    expect(ownerStakedAmount).to.equal(0);

    ownerStakedAmount = await launchPool.stakesOf(owner.address, token2.address);
    expect(ownerStakedAmount).to.equal(0);

    ownerStakedAmount = await launchPool.stakesOf(owner.address, token3.address);
    expect(ownerStakedAmount).to.equal(0);
  });

  it("Stake token1 and get amount staked", async function() {
    await expect(launchPool.stake(token1.address, 10))
        .to.emit(launchPool, "Staked")
        .withArgs(owner.address, token1.address, 10);

    const ownerErc20Balance = await token1.balanceOf(owner.address);
    expect(ownerErc20Balance).to.equal(90);

    const ownerStakedAmount = await launchPool.stakesOf(owner.address, token1.address);
    expect(ownerStakedAmount).to.equal(10);
  });

  it("Stake token1 then unstake", async function() {
    await expect(launchPool.stake(token1.address, 10))
        .to.emit(launchPool, "Staked")
        .withArgs(owner.address, token1.address, 10);

    let ownerErc20Balance = await token1.balanceOf(owner.address);
    expect(ownerErc20Balance).to.equal(90);

    await expect(launchPool.unstake(token1.address))
        .to.emit(launchPool, "Unstaked")
        .withArgs(owner.address, token1.address, 10);

    const ownerStakedAmount = await launchPool.stakesOf(owner.address, token1.address);
    expect(ownerStakedAmount).to.equal(0);

    ownerErc20Balance = await token1.balanceOf(owner.address);
    expect(ownerErc20Balance).to.equal(100);
  });

  it("Cannot stake token4", async function() {
    await expect(launchPool.stake(token4.address, 10))
        .to.be.reverted;
  });

  it("Stake all tokens and get amount staked", async function() {
    await expect(launchPool.stake(token1.address, 10))
        .to.emit(launchPool, "Staked")
        .withArgs(owner.address, token1.address, 10);

    await expect(launchPool.stake(token2.address, 10))
        .to.emit(launchPool, "Staked")
        .withArgs(owner.address, token2.address, 10);

    await expect(launchPool.stake(token3.address, 10))
        .to.emit(launchPool, "Staked")
        .withArgs(owner.address, token3.address, 10);

    let ownerErc20Balance = await token1.balanceOf(owner.address);
    expect(ownerErc20Balance).to.equal(90);

    ownerErc20Balance = await token2.balanceOf(owner.address);
    expect(ownerErc20Balance).to.equal(90);

    ownerErc20Balance = await token3.balanceOf(owner.address);
    expect(ownerErc20Balance).to.equal(90);

    let ownerStakedAmount = await launchPool.stakesOf(owner.address, token1.address);
    expect(ownerStakedAmount).to.equal(10);

    ownerStakedAmount = await launchPool.stakesOf(owner.address, token2.address);
    expect(ownerStakedAmount).to.equal(10);

    ownerStakedAmount = await launchPool.stakesOf(owner.address, token3.address);
    expect(ownerStakedAmount).to.equal(10);
  });

});
