const { expect } = require("chai");
const { ethers } = require("hardhat");

const initialAmount = 100;

describe("Stake", function() {
  let owner, erc20, launchBoard;  

  beforeEach("create and deploy erc and stake", async () => {
    [ owner ] = await ethers.getSigners();

    const MockERC20 = await ethers.getContractFactory("MockERC20");
    erc20 = await MockERC20.deploy(initialAmount);

    const LaunchPool = await ethers.getContractFactory("LaunchPool");
    launchPool = await LaunchPool.deploy(erc20.address, "testpool1", 50, 1000);
  });

  it("Owner's amount is initially zero", async function() {
    const ownerStakedAmount = await launchPool.stakesOf(owner.address);
    expect(ownerStakedAmount).to.equal(0);
  });

  it("Stake and get amount staked", async function() {
    await erc20.approve(launchPool.address, 10);  

    await expect(launchPool.stake(10))
        .to.emit(launchPool, "Staked")
        .withArgs(owner.address, 10);

    const ownerErc20Balance = await erc20.balanceOf(owner.address);
    expect(ownerErc20Balance).to.equal(90);

    const ownerStakedAmount = await launchPool.stakesOf(owner.address);
    expect(ownerStakedAmount).to.equal(10);
  });

  it("Stake then unstake", async function() {
    await erc20.approve(launchPool.address, 10);  

    await expect(launchPool.stake(10))
        .to.emit(launchPool, "Staked")
        .withArgs(owner.address, 10);

    let ownerErc20Balance = await erc20.balanceOf(owner.address);
    expect(ownerErc20Balance).to.equal(90);

    await expect(launchPool.unstake())
        .to.emit(launchPool, "Unstaked")
        .withArgs(owner.address, 10);

    const ownerStakedAmount = await launchPool.stakesOf(owner.address);
    expect(ownerStakedAmount).to.equal(0);

    ownerErc20Balance = await erc20.balanceOf(owner.address);
    expect(ownerErc20Balance).to.equal(100);
  });
});
