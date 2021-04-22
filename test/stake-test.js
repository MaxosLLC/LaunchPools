const { expect } = require("chai");
const { ethers } = require("hardhat");

const initialAmount = 100;

describe("Stake with no time lock", function() {
  let owner, acc1, token1, token2, token3, token4, launchPool;

  beforeEach("create and deploy erc and stake", async () => {
    [ owner, acc1 ] = await ethers.getSigners();

    MockERC20 = await ethers.getContractFactory("MockERC20");
    token1 = await MockERC20.deploy(initialAmount);
    token2 = await MockERC20.deploy(initialAmount);
    token3 = await MockERC20.deploy(initialAmount);
    token4 = await MockERC20.deploy(initialAmount);

    const currentTime = Math.round(Date.now() / 1000);

    const LaunchPool = await ethers.getContractFactory("LaunchPool");
    launchPool = await LaunchPool.deploy(
      [token1.address, token2.address, token3.address],
      "testpool1",
      50,
      1000,
      currentTime + 3600
      );

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

    expect(await launchPool.stakesOf(owner.address, token1.address)).to.equal(10);
    expect(await launchPool.totalStakesOf(owner.address)).to.equal(10);
    expect(await launchPool.totalStakes()).to.equal(10);
  });

  it("Stake token1 then unstake", async function() {
    await expect(launchPool.stake(token1.address, 10))
        .to.emit(launchPool, "Staked")
        .withArgs(owner.address, token1.address, 10);

    expect(await token1.balanceOf(owner.address)).to.equal(90);

    await expect(launchPool.unstake(token1.address))
        .to.emit(launchPool, "Unstaked")
        .withArgs(owner.address, token1.address, 10);

    expect(await launchPool.stakesOf(owner.address, token1.address)).to.equal(0);
    expect(await launchPool.totalStakesOf(owner.address)).to.equal(0);
    expect(await launchPool.totalStakes()).to.equal(0);

    expect(await token1.balanceOf(owner.address)).to.equal(100);
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

    expect(await token1.balanceOf(owner.address)).to.equal(90);
    expect(await token2.balanceOf(owner.address)).to.equal(90);
    expect(await token3.balanceOf(owner.address)).to.equal(90);

    expect(await launchPool.totalStakesOf(owner.address)).to.equal(30);
    expect(await launchPool.totalStakes()).to.equal(30);
  });

  it("Stake multiple tokens, multiple users", async function() {
    await token1.mint(acc1.address, 100);
    await token1.connect(acc1).approve(launchPool.address, 100);

    await token2.mint(acc1.address, 100);
    await token2.connect(acc1).approve(launchPool.address, 100);

    // Stake from the creator of the contract
    await expect(launchPool.stake(token1.address, 10))
        .to.emit(launchPool, "Staked")
        .withArgs(owner.address, token1.address, 10);

    await expect(launchPool.stake(token2.address, 10))
        .to.emit(launchPool, "Staked")
        .withArgs(owner.address, token2.address, 10);

    // Stake from another account
    await expect(launchPool.connect(acc1).stake(token1.address, 10))
        .to.emit(launchPool, "Staked")
        .withArgs(acc1.address, token1.address, 10);

    await expect(launchPool.connect(acc1).stake(token2.address, 10))
        .to.emit(launchPool, "Staked")
        .withArgs(acc1.address, token2.address, 10);

    expect(await token1.balanceOf(owner.address)).to.equal(90);
    expect(await token2.balanceOf(owner.address)).to.equal(90);
    expect(await token1.balanceOf(acc1.address)).to.equal(90);
    expect(await token2.balanceOf(acc1.address)).to.equal(90);

    expect(await launchPool.totalStakesOf(owner.address)).to.equal(20);
    expect(await launchPool.totalStakesOf(acc1.address)).to.equal(20);
    expect(await launchPool.totalStakes()).to.equal(40);
  });
});

describe("Stake with timelock", function() {
  let owner, acc1, token1, launchPool;

  beforeEach("create and deploy contracts", async () => {
    [ owner, acc1 ] = await ethers.getSigners();

    MockERC20 = await ethers.getContractFactory("MockERC20");
    token1 = await MockERC20.deploy(initialAmount);

    // We use 15 because https://consensys.github.io/smart-contract-best-practices/recommendations/#the-15-second-rule
    const currentTime = Math.round(Date.now() / 1000) - 15;

    const LaunchPool = await ethers.getContractFactory("LaunchPool");
    launchPool = await LaunchPool.deploy(
      [token1.address],
      "testpool1",
      50,
      1000,
      currentTime
      );

    await token1.approve(launchPool.address, 100);
    await token1.connect(acc1).approve(launchPool.address, 100);
  });

  it("fails because pool is closed", async () => {
    await expect(launchPool.stake(token1.address, 10))
        .to.be.revertedWith("LaunchPool is closed");

    await expect(launchPool.connect(acc1).stake(token1.address, 10))
        .to.be.revertedWith("LaunchPool is closed");
  })
});

describe("Stake with commitments", function() {
  let owner, acc1, token1, launchPool;

  beforeEach("create and deploy contracts", async () => {
    [ owner, acc1 ] = await ethers.getSigners();

    MockERC20 = await ethers.getContractFactory("MockERC20");
    token1 = await MockERC20.deploy(initialAmount);

    const currentTime = Math.round(Date.now() / 1000) + 3600;

    const LaunchPool = await ethers.getContractFactory("LaunchPool");
    launchPool = await LaunchPool.deploy(
      [token1.address],
      "testpool1",
      50,
      60,
      currentTime
      );

    await token1.approve(launchPool.address, 100);
    await token1.mint(acc1.address, 100);
    await token1.connect(acc1).approve(launchPool.address, 100);
  });

  it("Stake until can no longer stake", async () => {
    await expect(launchPool.connect(acc1).stake(token1.address, 40))
        .to.emit(launchPool, "Staked")
        .withArgs(acc1.address, token1.address, 40);

    expect(await launchPool.isFunded()).to.equal(false);

    await expect(launchPool.connect(acc1).stake(token1.address, 10))
        .to.emit(launchPool, "Staked")
        .withArgs(acc1.address, token1.address, 10);

    expect(await launchPool.isFunded()).to.equal(true);

    await expect(launchPool.stake(token1.address, 11))
        .to.be.revertedWith("Maximum staked amount exceeded");

    await expect(launchPool.stake(token1.address, 10))
        .to.emit(launchPool, "Staked")
        .withArgs(owner.address, token1.address, 10);

    expect(await launchPool.isFunded()).to.equal(true);

    await expect(launchPool.stake(token1.address, 1))
        .to.be.revertedWith("Maximum staked amount exceeded");
  })
});