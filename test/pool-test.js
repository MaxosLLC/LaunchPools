const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LauncPool with no timelock", function() {

  const initialAmount = 100;
  let owner, acc1, acc2, token1, token2, token3, stakeVault, launchPool;

  beforeEach("create and deploy contracts", async () => {
    [ owner, acc1, acc2 ] = await ethers.getSigners();

    MockERC20 = await ethers.getContractFactory("MockERC20");
    token1 = await MockERC20.deploy(initialAmount);
    token2 = await MockERC20.deploy(initialAmount);
    token3 = await MockERC20.deploy(initialAmount);

    const StakeVault = await ethers.getContractFactory("StakeVault");
    stakeVault = await StakeVault.deploy();

    const LaunchPool = await ethers.getContractFactory("LaunchPool");
    launchPool = await LaunchPool.deploy(
      [token1.address, token2.address],
      "testpool1",
      86400,
      3600,
      100,
      10000,
      stakeVault.address
    );

    await stakeVault.setPoolContract(launchPool.address);

    await token1.approve(stakeVault.address, 100);
    await token2.approve(stakeVault.address, 100);
    await token3.approve(stakeVault.address, 100);
  });

  async function _mintTokensAndApprove(token, account, amount) {
    await token.mint(account.address, amount);
    await token.connect(account).approve(stakeVault.address, amount);
  }

  it("Cannot stake token3", async function() {
    await expect(launchPool.stake(token3.address, 10))
        .to.be.reverted;
  })

  it("Cannot Deploy with more than 3 tokens", async function() {
    const LaunchPool = await ethers.getContractFactory("LaunchPool");
    await expect(LaunchPool.deploy(
      [token1.address, token2.address, token3.address, token1.address],
      "testpool1",
      86400,
      3600,
      100,
      10000,
      stakeVault.address
    )).to.be.reverted;
  });

  it("Everyone has zero stakes", async function() {
    expect(await launchPool.stakesOf(owner.address)).to.eql([]);
    expect(await launchPool.stakeCount()).to.equal(0);
    expect(await stakeVault.totalDeposited()).to.equal(0);
  });

  it("Cannot unstake someone else's stake", async function() {
    await _mintTokensAndApprove(token1, acc1, 100);

    await expect(launchPool.connect(acc1).stake(token1.address, 10))
        .to.emit(launchPool, "Staked")
        .withArgs(acc1.address, token1.address, 10, 1);

    await expect(launchPool.unstake(1))
        .to.be.reverted;
  });

  it("Stake token1 and get amount staked", async function() {
    await expect(launchPool.stake(token1.address, 10))
        .to.emit(launchPool, "Staked")
        .withArgs(owner.address, token1.address, 10, 1);

    expect(await token1.balanceOf(owner.address)).to.equal(90);

    expect((await launchPool.stakesOf(owner.address))[0]).to.equal(1);
    expect(await launchPool.stakeCount()).to.equal(1);

    expect(await stakeVault.depositsOf(owner.address)).to.equal(10);
    expect(await stakeVault.totalDeposited()).to.equal(10);
  });

  it("Stake token1 and then unstake", async function() {
    await expect(launchPool.stake(token1.address, 10))
        .to.emit(launchPool, "Staked")
        .withArgs(owner.address, token1.address, 10, 1);

    expect(await token1.balanceOf(owner.address)).to.equal(90);
    expect(await launchPool.stakeCount()).to.equal(1);
    expect((await launchPool.stakesOf(owner.address))[0]).to.equal(1);

    await expect(launchPool.unstake(1))
        .to.emit(launchPool, "Unstaked")
        .withArgs(owner.address, token1.address, 10, 1);

    expect(await token1.balanceOf(owner.address)).to.equal(100);
    expect(await launchPool.stakeCount()).to.equal(0);
    expect(await launchPool.stakesOf(owner.address)).to.eql([]);

    expect(await stakeVault.depositsOf(owner.address)).to.equal(0);
    expect(await stakeVault.totalDeposited()).to.equal(0);
  });

  it("Stake token1 and token2 by one account", async function() {
    await _mintTokensAndApprove(token1, acc1, 100);
    await _mintTokensAndApprove(token2, acc1, 100);

    await expect(launchPool.connect(acc1).stake(token1.address, 10))
        .to.emit(launchPool, "Staked")
        .withArgs(acc1.address, token1.address, 10, 1);

    await expect(launchPool.connect(acc1).stake(token1.address, 20))
        .to.emit(launchPool, "Staked")
        .withArgs(acc1.address, token1.address, 20, 2);

    await expect(launchPool.connect(acc1).stake(token2.address, 30))
        .to.emit(launchPool, "Staked")
        .withArgs(acc1.address, token2.address, 30, 3);

    expect(await token1.balanceOf(acc1.address)).to.equal(70);
    expect(await token2.balanceOf(acc1.address)).to.equal(70);
    expect(await launchPool.stakeCount()).to.equal(3);
    expect((await launchPool.stakesOf(acc1.address))[0]).to.equal(1);
    expect((await launchPool.stakesOf(acc1.address))[1]).to.equal(2);
    expect((await launchPool.stakesOf(acc1.address))[2]).to.equal(3);
    expect(await stakeVault.depositsOf(acc1.address)).to.equal(60);
    expect(await stakeVault.totalDeposited()).to.equal(60);

    await expect(launchPool.connect(acc1).unstake(3))
        .to.emit(launchPool, "Unstaked")
        .withArgs(acc1.address, token2.address, 30, 3);

    expect(await token2.balanceOf(acc1.address)).to.equal(100);
    expect(await launchPool.stakeCount()).to.equal(2);
    expect((await launchPool.stakesOf(acc1.address)).length).to.equal(2);
    expect(await stakeVault.depositsOf(acc1.address)).to.equal(30);
    expect(await stakeVault.totalDeposited()).to.equal(30);
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