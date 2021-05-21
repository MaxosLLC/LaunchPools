const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Test stake vault", function() {
  let owner, acc1, acc2, recvFunds, token1, token2, token3, token4, stakeVault;

  const initialAmount = 100;
  const poolId1 = "00";
  const poolId2 = "01";

  async function _mintTokensAndApprove(token, account, amount) {
    await token.mint(account.address, amount);
    await token.connect(account).approve(stakeVault.address, amount);
  }

  beforeEach("create and deploy erc and vault with 1 pool", async () => {
    [ owner, acc1, acc2, recvFunds ] = await ethers.getSigners();

    MockERC20 = await ethers.getContractFactory("MockERC20");
    token1 = await MockERC20.deploy(initialAmount);
    token2 = await MockERC20.deploy(initialAmount);
    token3 = await MockERC20.deploy(initialAmount);
    token4 = await MockERC20.deploy(initialAmount);

    const StakeVault = await ethers.getContractFactory("StakeVault");
    stakeVault = await StakeVault.deploy(recvFunds.address);

    // Little of a hack here.
    stakeVault.setPoolContract(owner.address);

    await token1.approve(stakeVault.address, 100);
    await token2.approve(stakeVault.address, 100);
    await token3.approve(stakeVault.address, 100);

    await _mintTokensAndApprove(token1, acc1, 100);
    await _mintTokensAndApprove(token1, acc2, 100);
  });

  it("Call before setting LaunchPool contract", async function() {
    const StakeVault = await ethers.getContractFactory("StakeVault");
    const notInitted = await StakeVault.deploy(recvFunds.address);

    await expect(notInitted.depositStake(poolId1, token1.address, 10, owner)).to.be.reverted;
  });

  it("Nothing in vault", async function() {
    expect(await stakeVault.depositsOfByToken(poolId1, owner.address, token1.address)).to.equal(0);
    expect(await stakeVault.depositsOfByToken(poolId2, owner.address, token1.address)).to.equal(0);

    expect(await stakeVault.depositsOfByToken(poolId1, owner.address, token2.address)).to.equal(0);
    expect(await stakeVault.depositsOfByToken(poolId2, owner.address, token2.address)).to.equal(0);

    expect(await stakeVault.depositsOfByToken(poolId1, owner.address, token3.address)).to.equal(0);
    expect(await stakeVault.depositsOfByToken(poolId2, owner.address, token3.address)).to.equal(0);
    expect(await stakeVault.totalDeposited()).to.equal(0);
  });

  it("Deposit token1 and get amount staked", async function() {
    await stakeVault.depositStake(poolId1, token1.address, 10, owner.address);

    expect(await token1.balanceOf(owner.address)).to.equal(90);

    expect(await stakeVault.depositsOfByToken(poolId1, owner.address, token1.address)).to.equal(10);
    expect(await stakeVault.depositsOf(poolId1, owner.address)).to.equal(10);
    expect(await stakeVault.totalDeposited()).to.equal(10);
  });

  it("Deposit token1 then withdraw", async function() {
    await stakeVault.depositStake(poolId1, token1.address, 10, owner.address);

    expect(await stakeVault.depositsOfByToken(poolId1, owner.address, token1.address)).to.equal(10);
    expect(await token1.balanceOf(owner.address)).to.equal(90);

    await stakeVault.withdrawStake(poolId1, token1.address, 5, owner.address);

    expect(await stakeVault.depositsOfByToken(poolId1, owner.address, token1.address)).to.equal(5);
    expect(await stakeVault.depositsOf(poolId1, owner.address)).to.equal(5);
    expect(await stakeVault.totalDeposited()).to.equal(5);

    expect(await token1.balanceOf(owner.address)).to.equal(95);
  });

  it("Stake all tokens and get amount staked", async function() {
    await stakeVault.depositStake(poolId1, token1.address, 10, owner.address);
    await stakeVault.depositStake(poolId1, token2.address, 10, owner.address);
    await stakeVault.depositStake(poolId1, token3.address, 10, owner.address);

    expect(await token1.balanceOf(owner.address)).to.equal(90);
    expect(await token2.balanceOf(owner.address)).to.equal(90);
    expect(await token3.balanceOf(owner.address)).to.equal(90);

    expect(await stakeVault.depositsOf(poolId1, owner.address)).to.equal(30);
    expect(await stakeVault.totalDeposited()).to.equal(30);
  });

  it("Stake multiple tokens, multiple users", async function() {
    _mintTokensAndApprove(token2, acc1, 100);

    await stakeVault.depositStake(poolId1, token1.address, 10, owner.address);
    await stakeVault.depositStake(poolId1, token2.address, 10, owner.address);

    // Deposit from another account
    await stakeVault.depositStake(poolId1, token1.address, 10, acc1.address);
    await stakeVault.depositStake(poolId1, token2.address, 10, acc1.address);

    expect(await token1.balanceOf(owner.address)).to.equal(90);
    expect(await token2.balanceOf(owner.address)).to.equal(90);
    expect(await token1.balanceOf(acc1.address)).to.equal(90);
    expect(await token2.balanceOf(acc1.address)).to.equal(90);

    expect(await stakeVault.depositsOf(poolId1, owner.address)).to.equal(20);
    expect(await stakeVault.depositsOf(poolId1, acc1.address)).to.equal(20);
    expect(await stakeVault.totalDeposited()).to.equal(40);
  });

  it("Withdraw with wrong account", async function() {
    await stakeVault.depositStake(poolId1, token1.address, 10, owner.address);
    await stakeVault.depositStake(poolId1, token2.address, 10, owner.address);
    await stakeVault.depositStake(poolId1, token3.address, 10, owner.address);

    await expect(stakeVault.connect(acc1).encumber(poolId1, owner.address, token1.address, 10))
      .to.be.reverted;
    await expect(stakeVault.connect(acc1).withdraw(poolId1)).to.be.reverted;
  });

  it("Stake multiple tokens by one account then withdraw", async function() {
    await stakeVault.depositStake(poolId1, token1.address, 10, owner.address);
    await stakeVault.depositStake(poolId1, token2.address, 10, owner.address);
    await stakeVault.depositStake(poolId1, token3.address, 10, owner.address);

    await stakeVault.encumber(poolId1, owner.address, token1.address, 10);
    await stakeVault.encumber(poolId1, owner.address, token2.address, 10);
    await stakeVault.encumber(poolId1, owner.address, token3.address, 10);

    await stakeVault.withdraw(poolId1);

    expect(await token1.balanceOf(recvFunds.address)).to.equal(10);
    expect(await token2.balanceOf(recvFunds.address)).to.equal(10);
    expect(await token3.balanceOf(recvFunds.address)).to.equal(10);

    expect(await stakeVault.totalDeposited()).to.equal(0);
  });

  it("Stake multiple accounts then withdraw", async function() {
    await stakeVault.depositStake(poolId1, token1.address, 10, acc1.address);
    await stakeVault.depositStake(poolId1, token1.address, 10, acc1.address);
    await stakeVault.depositStake(poolId1, token1.address, 10, acc2.address);
    await stakeVault.depositStake(poolId1, token1.address, 10, acc2.address);
    await stakeVault.depositStake(poolId1, token1.address, 10, owner.address);
    await stakeVault.depositStake(poolId1, token1.address, 10, owner.address);

    await stakeVault.encumber(poolId1, acc1.address, token1.address, 10);
    await stakeVault.encumber(poolId1, acc2.address, token1.address, 10);
    await stakeVault.encumber(poolId1, owner.address, token1.address, 10);

    await stakeVault.withdraw(poolId1);

    expect(await token1.balanceOf(recvFunds.address)).to.equal(30);
    expect(await token2.balanceOf(recvFunds.address)).to.equal(0);
    expect(await token3.balanceOf(recvFunds.address)).to.equal(0);

    expect(await stakeVault.totalDeposited()).to.equal(30);
  });
});
