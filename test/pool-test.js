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

    stakeVault = await _deployStakeVault();

    const LaunchPoolTracker = await ethers.getContractFactory("LaunchPoolTracker");
    launchPoolTracker = await LaunchPoolTracker.deploy(
      [token1.address, token2.address],
      stakeVault
    );

    // await token1.approve(stakeVault.address, 100);
    // await token2.approve(stakeVault.address, 100);
    // await token3.approve(stakeVault.address, 100);

    firstPoolId = await _addPool(launchPoolTracker);
  });

  // it("Cannot stake token3", async function() {
  //   await expect(launchPoolTracker.addStake(0, token3.address, 10))
  //       .to.be.reverted;
  // });

  // it("Only owner can setOffer", async function() {
  //   await expect(launchPool.connect(acc1).setOffer(firstPoolId, "asdf"))
  //       .to.be.reverted;

  //   await launchPool.setOffer(firstPoolId, "asdf");
  //   const offer = (await launchPool.poolsById(firstPoolId)).offer;
  //   expect(offer.url).to.equal("asdf");
  // });

  // it("Cannot Deploy with more than 3 tokens", async function() {
  //   const LaunchPool = await ethers.getContractFactory("LaunchPoolTracker");
  //   await expect(LaunchPool.deploy(
  //     [token1.address, token2.address, token3.address, token1.address],
  //     stakeVault.address
  //   )).to.be.reverted;
  // });

  // it("Everyone has zero stakes", async function() {
  //   expect(await launchPool.stakesOf(firstPoolId, owner.address)).to.eql([]);
  //   expect(await launchPool.poolStakeCount(firstPoolId)).to.equal(0);
  //   expect(await stakeVault.totalDeposited()).to.equal(0);
  // });

  // it("Cannot unstake someone else's stake", async function() {
  //   await _mintTokensAndApprove(token1, acc1, 100);

  //   await expect(launchPool.connect(acc1).stake(firstPoolId, token1.address, 10))
  //       .to.emit(launchPool, "Staked")
  //       .withArgs(firstPoolId, acc1.address, token1.address, 10, 1);

  //   await expect(launchPool.unstake(firstPoolId, 1))
  //       .to.be.reverted;
  // });

  // it("Stake token1 and get amount staked", async function() {
  //   await expect(launchPool.stake(firstPoolId, token1.address, 10))
  //       .to.emit(launchPool, "Staked")
  //       .withArgs(firstPoolId, owner.address, token1.address, 10, 1);

  //   expect(await token1.balanceOf(owner.address)).to.equal(90);

  //   expect((await launchPool.stakesOf(firstPoolId, owner.address))[0]).to.equal(1);
  //   expect(await launchPool.poolStakeCount(firstPoolId)).to.equal(1);

  //   expect(await stakeVault.depositsOfPool(firstPoolId)).to.equal(10);
  //   expect(await stakeVault.depositsOf(firstPoolId, owner.address)).to.equal(10);
  // });

  // it("Stake token1 and then unstake", async function() {
  //   await expect(launchPool.stake(firstPoolId, token1.address, 10))
  //       .to.emit(launchPool, "Staked")
  //       .withArgs(firstPoolId, owner.address, token1.address, 10, 1);

  //   expect(await token1.balanceOf(owner.address)).to.equal(90);
  //   expect(await launchPool.poolStakeCount(firstPoolId)).to.equal(1);
  //   expect((await launchPool.stakesOf(firstPoolId, owner.address))[0]).to.equal(1);

  //   await expect(launchPool.unstake(firstPoolId, 1))
  //       .to.emit(launchPool, "Unstaked")
  //       .withArgs(firstPoolId, owner.address, token1.address, 10, 1);

  //   expect(await token1.balanceOf(owner.address)).to.equal(100);
  //   expect((await launchPool.stakesOf(firstPoolId, owner.address))).to.eql([]);
  //   expect(await launchPool.poolStakeCount(firstPoolId)).to.equal(0);

  //   expect(await stakeVault.depositsOf(firstPoolId, owner.address)).to.equal(0);
  //   expect(await stakeVault.depositsOfPool(firstPoolId)).to.equal(0);
  // });

  // it("Stake/unstake token1 and token2 by multiple accounts", async function() {
  //   await _mintTokensAndApprove(token1, acc1, 100);
  //   await _mintTokensAndApprove(token2, acc1, 100);
  //   await _mintTokensAndApprove(token1, acc2, 100);
  //   await _mintTokensAndApprove(token2, acc2, 100);

  //   await expect(launchPool.connect(acc1).stake(firstPoolId, token1.address, 10))
  //       .to.emit(launchPool, "Staked")
  //       .withArgs(firstPoolId, acc1.address, token1.address, 10, 1);

  //   await expect(launchPool.connect(acc2).stake(firstPoolId, token1.address, 15))
  //       .to.emit(launchPool, "Staked")
  //       .withArgs(firstPoolId, acc2.address, token1.address, 15, 2);

  //   await expect(launchPool.connect(acc1).stake(firstPoolId, token2.address, 25))
  //       .to.emit(launchPool, "Staked")
  //       .withArgs(firstPoolId, acc1.address, token2.address, 25, 3);

  //   await expect(launchPool.connect(acc2).stake(firstPoolId, token2.address, 30))
  //       .to.emit(launchPool, "Staked")
  //       .withArgs(firstPoolId, acc2.address, token2.address, 30, 4);

  //   expect(await token1.balanceOf(acc1.address)).to.equal(90);
  //   expect(await token1.balanceOf(acc2.address)).to.equal(85);
  //   expect(await token2.balanceOf(acc1.address)).to.equal(75);
  //   expect(await token2.balanceOf(acc2.address)).to.equal(70);

  //   expect(await launchPool.poolStakeCount(firstPoolId)).to.equal(4);
  //   expect((await launchPool.stakesOf(firstPoolId, acc1.address)).length).to.equal(2);
  //   expect((await launchPool.stakesOf(firstPoolId, acc2.address)).length).to.equal(2);

  //   expect(await stakeVault.depositsOf(firstPoolId, acc1.address)).to.equal(35);
  //   expect(await stakeVault.depositsOfPool(firstPoolId)).to.equal(80);

  //   await expect(launchPool.connect(acc1).unstake(firstPoolId, 1))
  //       .to.emit(launchPool, "Unstaked")
  //       .withArgs(firstPoolId, acc1.address, token1.address, 10, 1);

  //   await expect(launchPool.connect(acc1).unstake(firstPoolId, 3))
  //       .to.emit(launchPool, "Unstaked")
  //       .withArgs(firstPoolId, acc1.address, token2.address, 25, 3);

  //   expect(await token2.balanceOf(acc1.address)).to.equal(100);
  //   expect(await launchPool.poolStakeCount(firstPoolId)).to.equal(2);
  //   expect((await launchPool.stakesOf(firstPoolId, acc1.address)).length).to.equal(0);
  //   expect((await launchPool.stakesOf(firstPoolId, acc2.address)).length).to.equal(2);
  //   expect(await stakeVault.depositsOf(firstPoolId, acc1.address)).to.equal(0);
  //   expect(await stakeVault.depositsOfPool(firstPoolId)).to.equal(45);
  // });
});

// describe("Staking and Committing", function() {
//   let owner, acc1, acc2, token1, stakeVault, launchPool, firstPoolId;

//   beforeEach("create and deploy contracts", async () => {
//     [ owner, acc1, acc2 ] = await ethers.getSigners();

//     const MockERC20 = await ethers.getContractFactory("MockERC20");
//     token1 = await MockERC20.deploy(100);

//     stakeVault = await _deployStakeVault(owner);

//     const LaunchPool = await ethers.getContractFactory("LaunchPoolTracker");
//     launchPool = await LaunchPool.deploy(
//       [token1.address],
//       stakeVault.address
//     );

//     await stakeVault.setPoolContract(launchPool.address);
//     await token1.mint(acc1.address, 100);
//     await token1.connect(acc1).approve(stakeVault.address, 100);

//     firstPoolId = await _addLaunchPool(launchPool);
//   });

//   it("Stake token1 commit it", async function() {
//     await expect(launchPool.connect(acc1).stake(firstPoolId, token1.address, 5))
//         .to.emit(launchPool, "Staked")
//         .withArgs(firstPoolId, acc1.address, token1.address, 5, 1);

//     await expect(launchPool.connect(acc1).stake(firstPoolId, token1.address, 4))
//         .to.emit(launchPool, "Staked")
//         .withArgs(firstPoolId, acc1.address, token1.address, 4, 2);

//     await launchPool.setOffer(firstPoolId, "asdf");

//     await expect(launchPool.connect(acc1).stake(firstPoolId, token1.address, 2))
//         .to.emit(launchPool, "Staked")
//         .withArgs(firstPoolId, acc1.address, token1.address, 2, 3);

//     await expect(launchPool.connect(acc1).commit(firstPoolId, 1))
//         .to.emit(launchPool, "Committed")
//         .withArgs(firstPoolId, acc1.address, 1);

//     await expect(launchPool.connect(acc1).commit(firstPoolId, 1))
//         .to.be.reverted;

//     await expect(launchPool.connect(acc1).unstake(firstPoolId, 1))
//         .to.be.reverted;

//     await expect(launchPool.connect(acc1).commit(firstPoolId, 2))
//         .to.emit(launchPool, "Committed")
//         .withArgs(firstPoolId, acc1.address, 2);

//     expect(await launchPool.poolTotalCommitments(firstPoolId)).to.equal(9);
//     expect(await launchPool.canRedeemOffer(firstPoolId)).to.equal(false);

//     await expect(launchPool.connect(acc1).commit(firstPoolId, 3))
//         .to.emit(launchPool, "Committed")
//         .withArgs(firstPoolId, acc1.address, 3);

//     await expect(launchPool.connect(acc1).commit(firstPoolId, 4))
//         .to.be.reverted;

//     expect(await launchPool.poolTotalCommitments(firstPoolId)).to.equal(11);
//     const commitments = await launchPool.poolTotalCommitments(firstPoolId);
//     const minCommit = (await launchPool.poolsById(firstPoolId)).offer.bounds.minimum;
//     expect(commitments.toNumber() >= minCommit.toNumber()).to.equal(true)
//   });
// });

// describe("timing errors", () => {
//   it("fails because pool is closed", async () => {
//     const [_, acc1] = await ethers.getSigners();

//     const MockERC20 = await ethers.getContractFactory("MockERC20");
//     const token1 = await MockERC20.deploy(100);

//     const stakeVault = await _deployStakeVault(acc1);
//     const LaunchPool = await ethers.getContractFactory("LaunchPoolTracker");
//     const launchPool = await LaunchPool.deploy(
//       [token1.address],
//       stakeVault.address
//     );

//     await launchPool.addLaunchPool(
//       "testpool1",
//       0,
//       0,
//       10,
//       10000,
//     );

//     await expect(launchPool.connect(acc1).stake(1, token1.address, 10))
//         .to.be.revertedWith("LaunchPool is closed");

//     await expect(launchPool.connect(acc1).stake(1, token1.address, 10))
//         .to.be.revertedWith("LaunchPool is closed");

//     await expect(launchPool.connect(acc1).commit(1, 1))
//         .to.be.reverted;
//   });
// });

// describe("Stake and redeem offer", () => {
//   let owner, acc1, acc2, rcvAcc, token1, token2, stakeVault, launchPool, firstPoolId;

//   async function _mintTokensAndApprove(token, account, amount) {
//     await token.mint(account.address, amount);
//     await token.connect(account).approve(stakeVault.address, amount);
//   }

//   async function _deployPool(offerValidTime) {
//     [ owner, acc1, acc2, rcvAcc ] = await ethers.getSigners();

//     MockERC20 = await ethers.getContractFactory("MockERC20");
//     token1 = await MockERC20.deploy(100);
//     token2 = await MockERC20.deploy(100);

//     stakeVault = await _deployStakeVault(rcvAcc);

//     const LaunchPool = await ethers.getContractFactory("LaunchPoolTracker");
//     launchPool = await LaunchPool.deploy(
//       [token1.address, token2.address],
//       stakeVault.address
//     );

//     await launchPool.addLaunchPool(
//       "testpool1",
//       60 * 60 * 24 * 7, // 7 days
//       offerValidTime,
//       100,
//       10000,
//     );

//     firstPoolId = await launchPool.poolIds(0);

//     await stakeVault.setPoolContract(launchPool.address);
//     await launchPool.setOffer(firstPoolId, "asdf");

//     await _mintTokensAndApprove(token1, acc1, 100);
//     await _mintTokensAndApprove(token1, acc2, 100);

//     await _mintTokensAndApprove(token2, acc1, 100);
//     await _mintTokensAndApprove(token2, acc2, 100);
//   }

//   async function _stakeAndCommit(account, token, amount) {
//     const tx = await launchPool.connect(account).stake(firstPoolId, token.address, amount);
//     const receipt = await tx.wait(0);

//     const stakeEvent = receipt.events.filter(evt => evt?.event === 'Staked')[0];
//     const stakeId = stakeEvent.args.stakeId;
//     await launchPool.connect(account).commit(firstPoolId, stakeId);
//   }

//   beforeEach("setup pool", async () => {
//     await _deployPool(86400);
//   })

//   it("cannot redeem when offer is still open", async () => {
//     await _stakeAndCommit(acc1, token1, 10);
//     await _stakeAndCommit(acc1, token2, 50);
//     await _stakeAndCommit(acc1, token1, 50);

//     expect(await launchPool.canRedeemOffer(firstPoolId)).to.equal(false);
//     await expect(launchPool.redeemOffer(firstPoolId)).to.be.reverted;
//   });

//   _advanceTimeAndMineBlock = async () => {
//     await owner.provider.send('evm_increaseTime', [60 * 60 * 25]);
//     await owner.provider.send('evm_mine');
//   }

//   it("C,S and redeem with only one account", async () => {
//     await _stakeAndCommit(acc1, token1, 10);
//     await _stakeAndCommit(acc1, token2, 50);
//     await _stakeAndCommit(acc1, token1, 50);

//     expect(await launchPool.canRedeemOffer(firstPoolId)).to.equal(false);

//     _advanceTimeAndMineBlock();
//     expect(await launchPool.canRedeemOffer(firstPoolId)).to.equal(true);
//     await launchPool.redeemOffer(firstPoolId);

//     expect(await token1.balanceOf(acc1.address)).to.equal(40);
//     expect(await token2.balanceOf(acc1.address)).to.equal(50);
//     expect(await token1.balanceOf(rcvAcc.address)).to.equal(60);
//     expect(await token2.balanceOf(rcvAcc.address)).to.equal(50);
//   });
// });
