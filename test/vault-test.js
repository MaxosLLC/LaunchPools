const { expect } = require("chai");
const { ethers } = require("hardhat");


describe("Test stake vault", function() {
  let owner, acc1, token1, token2, token3, stakeVault;

  const initialAmount = 100;

  beforeEach("create and deploy erc and vault", async () => {
    [ owner, acc1 ] = await ethers.getSigners();

    MockERC20 = await ethers.getContractFactory("MockERC20");
    token1 = await MockERC20.deploy(initialAmount);
    token2 = await MockERC20.deploy(initialAmount);
    token3 = await MockERC20.deploy(initialAmount);
    token4 = await MockERC20.deploy(initialAmount);

    const StakeVault = await ethers.getContractFactory("StakeVault");
    stakeVault = await StakeVault.deploy();

    // Little of a hack here.
    stakeVault.setPoolContract(owner.address);

    await token1.approve(stakeVault.address, 100);
    await token2.approve(stakeVault.address, 100);
    await token3.approve(stakeVault.address, 100);
  });

  it("Call before setting LaunchPool contract", async function() {
    const StakeVault = await ethers.getContractFactory("StakeVault");
    const notInitted = await StakeVault.deploy();

    await expect(notInitted.depositStake(token1.address, 10, owner)).to.be.reverted;
  });

  it("Nothing in vault", async function() {
    expect(await stakeVault.getDepositsByToken(owner.address, token1.address)).to.equal(0);
    expect(await stakeVault.getDepositsByToken(owner.address, token2.address)).to.equal(0);
    expect(await stakeVault.getDepositsByToken(owner.address, token3.address)).to.equal(0);
    expect(await stakeVault.totalDeposited()).to.equal(0);
  });

  it("Deposit token1 and get amount staked", async function() {
    await stakeVault.depositStake(token1.address, 10, owner.address);

    expect(await token1.balanceOf(owner.address)).to.equal(90);

    expect(await stakeVault.getDepositsByToken(owner.address, token1.address)).to.equal(10);
    expect(await stakeVault.getDeposits(owner.address)).to.equal(10);
    expect(await stakeVault.totalDeposited()).to.equal(10);
  });

  it("Deposit token1 then withdraw", async function() {
    await stakeVault.depositStake(token1.address, 10, owner.address);

    expect(await stakeVault.getDepositsByToken(owner.address, token1.address)).to.equal(10);
    expect(await token1.balanceOf(owner.address)).to.equal(90);

    await stakeVault.withdrawStake(token1.address, 5, owner.address);

    expect(await stakeVault.getDepositsByToken(owner.address, token1.address)).to.equal(5);
    expect(await stakeVault.getDeposits(owner.address)).to.equal(5);
    expect(await stakeVault.totalDeposited()).to.equal(5);

    expect(await token1.balanceOf(owner.address)).to.equal(95);
  });

  it("Stake all tokens and get amount staked", async function() {
    await stakeVault.depositStake(token1.address, 10, owner.address);
    await stakeVault.depositStake(token2.address, 10, owner.address);
    await stakeVault.depositStake(token3.address, 10, owner.address);

    expect(await token1.balanceOf(owner.address)).to.equal(90);
    expect(await token2.balanceOf(owner.address)).to.equal(90);
    expect(await token3.balanceOf(owner.address)).to.equal(90);

    expect(await stakeVault.getDeposits(owner.address)).to.equal(30);
    expect(await stakeVault.totalDeposited()).to.equal(30);
  });

  it("Stake multiple tokens, multiple users", async function() {
    await token1.mint(acc1.address, 100);
    await token1.connect(acc1).approve(stakeVault.address, 100);

    await token2.mint(acc1.address, 100);
    await token2.connect(acc1).approve(stakeVault.address, 100);

    await stakeVault.depositStake(token1.address, 10, owner.address);
    await stakeVault.depositStake(token2.address, 10, owner.address);

    // Deposit from another account
    await stakeVault.depositStake(token1.address, 10, acc1.address);
    await stakeVault.depositStake(token2.address, 10, acc1.address);

    expect(await token1.balanceOf(owner.address)).to.equal(90);
    expect(await token2.balanceOf(owner.address)).to.equal(90);
    expect(await token1.balanceOf(acc1.address)).to.equal(90);
    expect(await token2.balanceOf(acc1.address)).to.equal(90);

    expect(await stakeVault.getDeposits(owner.address)).to.equal(20);
    expect(await stakeVault.getDeposits(acc1.address)).to.equal(20);
    expect(await stakeVault.totalDeposited()).to.equal(40);
  });
});
