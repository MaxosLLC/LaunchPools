const Stake = artifacts.require("Stake");
const IERC20 = artifacts.require("IERC20");

module.exports = function(deployer) {
  deployer.deploy(Stake, "0x61A6EA2A7Fd8e3a30A16B7CBA8de3A6F75089094");
  deployer.deploy(IERC20, "0xfD5280B4BC9ABe39C60B7489B4D39C477B365a1d");
};
