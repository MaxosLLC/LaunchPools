const { expect } = require("chai");
const { ethers } = require("hardhat");

async function _deployStakeVault() {
    const StakeVault = await ethers.getContractFactory("StakeVault");
    return await StakeVault.deploy();
}

describe("Staking in LaunchPool", function() {
  const initialAmount = 100;
  let owner, acc1, acc2, token1, token2, token3, stakeVault, launchPool;

  beforeEach("create and deploy contracts", async () => {
    [ owner, acc1, acc2 ] = await ethers.getSigners();

    MockERC20 = await ethers.getContractFactory("MockERC20");
    token1 = await MockERC20.deploy(initialAmount);
    token2 = await MockERC20.deploy(initialAmount);
    token3 = await MockERC20.deploy(initialAmount);

    stakeVault = await _deployStakeVault();

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
  });

  it("Only owner can setOffer", async function() {
    await expect(launchPool.connect(acc1).setOffer("asdf"))
        .to.be.reverted;

    await launchPool.setOffer("asdf");
    const offer = await launchPool.offer();
    expect(offer.url).to.equal("asdf");
  });

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

  it("Stake/unstake token1 and token2 by multiple accounts", async function() {
    await _mintTokensAndApprove(token1, acc1, 100);
    await _mintTokensAndApprove(token2, acc1, 100);
    await _mintTokensAndApprove(token1, acc2, 100);
    await _mintTokensAndApprove(token2, acc2, 100);

    await expect(launchPool.connect(acc1).stake(token1.address, 10))
        .to.emit(launchPool, "Staked")
        .withArgs(acc1.address, token1.address, 10, 1);

    await expect(launchPool.connect(acc2).stake(token1.address, 15))
        .to.emit(launchPool, "Staked")
        .withArgs(acc2.address, token1.address, 15, 2);

    await expect(launchPool.connect(acc1).stake(token2.address, 25))
        .to.emit(launchPool, "Staked")
        .withArgs(acc1.address, token2.address, 25, 3);

    await expect(launchPool.connect(acc2).stake(token2.address, 30))
        .to.emit(launchPool, "Staked")
        .withArgs(acc2.address, token2.address, 30, 4);

    expect(await token1.balanceOf(acc1.address)).to.equal(90);
    expect(await token1.balanceOf(acc2.address)).to.equal(85);
    expect(await token2.balanceOf(acc1.address)).to.equal(75);
    expect(await token2.balanceOf(acc2.address)).to.equal(70);

    expect(await launchPool.stakeCount()).to.equal(4);
    expect((await launchPool.stakesOf(acc1.address)).length).to.equal(2);
    expect((await launchPool.stakesOf(acc2.address)).length).to.equal(2);

    expect(await stakeVault.depositsOf(acc1.address)).to.equal(35);
    expect(await stakeVault.totalDeposited()).to.equal(80);

    await expect(launchPool.connect(acc1).unstake(1))
        .to.emit(launchPool, "Unstaked")
        .withArgs(acc1.address, token1.address, 10, 1);

    await expect(launchPool.connect(acc1).unstake(3))
        .to.emit(launchPool, "Unstaked")
        .withArgs(acc1.address, token2.address, 25, 3);

    expect(await token2.balanceOf(acc1.address)).to.equal(100);
    expect(await launchPool.stakeCount()).to.equal(2);
    expect((await launchPool.stakesOf(acc1.address)).length).to.equal(0);
    expect((await launchPool.stakesOf(acc2.address)).length).to.equal(2);
    expect(await stakeVault.depositsOf(acc1.address)).to.equal(0);
    expect(await stakeVault.totalDeposited()).to.equal(45);
  });
});

/**
 * Functionality left to add:
 * 1. Check which committed stakes are able to participate.
 * 2. Try to stake/unstake when you cannot (the state is closed).
 */

describe("Staking and Committing", function() {
  let owner, acc1, acc2, token1, launchPool;

  beforeEach("create and deploy contracts", async () => {
    [ owner, acc1, acc2 ] = await ethers.getSigners();

    MockERC20 = await ethers.getContractFactory("MockERC20");
    token1 = await MockERC20.deploy(100);

    stakeVault = await _deployStakeVault();

    const LaunchPool = await ethers.getContractFactory("LaunchPool");
    launchPool = await LaunchPool.deploy(
      [token1.address],
      "testpool1",
      86400,
      3600,
      10,
      10000,
      stakeVault.address
    );

    await stakeVault.setPoolContract(launchPool.address);
    await token1.mint(acc1.address, 100);
    await token1.connect(acc1).approve(stakeVault.address, 100);
  });


  it("Stake token1 commit it", async function() {
    await expect(launchPool.connect(acc1).stake(token1.address, 5))
        .to.emit(launchPool, "Staked")
        .withArgs(acc1.address, token1.address, 5, 1);

    await expect(launchPool.connect(acc1).stake(token1.address, 4))
        .to.emit(launchPool, "Staked")
        .withArgs(acc1.address, token1.address, 4, 2);

    await launchPool.setOffer("asdf");

    await expect(launchPool.connect(acc1).stake(token1.address, 2))
        .to.emit(launchPool, "Staked")
        .withArgs(acc1.address, token1.address, 2, 3);

    await expect(launchPool.connect(acc1).commit(1))
        .to.emit(launchPool, "Committed")
        .withArgs(acc1.address, 1);

    await expect(launchPool.connect(acc1).commit(1))
        .to.be.reverted;

    await expect(launchPool.connect(acc1).unstake(1))
        .to.be.reverted;

    await expect(launchPool.connect(acc1).commit(2))
        .to.emit(launchPool, "Committed")
        .withArgs(acc1.address, 2);

    expect(await launchPool.totalCommitments()).to.equal(9);
    expect(await launchPool.canRedeemOffer()).to.equal(false);

    await expect(launchPool.connect(acc1).commit(3))
        .to.emit(launchPool, "Committed")
        .withArgs(acc1.address, 3);

    await expect(launchPool.connect(acc1).commit(4))
        .to.be.reverted;

    expect(await launchPool.totalCommitments()).to.equal(11);
    expect(await launchPool.canRedeemOffer()).to.equal(true);
  });
});

describe("timing errors", () => {
  it("fails because pool is closed", async () => {
    const [_, acc1] = await ethers.getSigners();

    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const token1 = await MockERC20.deploy(100);

    const stakeVault = await _deployStakeVault();
    const LaunchPool = await ethers.getContractFactory("LaunchPool");
    launchPool = await LaunchPool.deploy(
      [token1.address],
      "testpool1",
      0,
      0,
      100,
      10000,
      stakeVault.address
    );
    await expect(launchPool.connect(acc1).stake(token1.address, 10))
        .to.be.revertedWith("LaunchPool is closed");

    await expect(launchPool.connect(acc1).stake(token1.address, 10))
        .to.be.revertedWith("LaunchPool is closed");

    await expect(launchPool.connect(acc1).commit(1))
        .to.be.reverted;
  });
});