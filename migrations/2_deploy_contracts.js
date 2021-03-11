const Stake = artifacts.require("Stake");

module.exports = function(deployer) {
  deployer.deploy(Stake, "0x61A6EA2A7Fd8e3a30A16B7CBA8de3A6F75089094");
};
