// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

import "./LaunchStake.sol";

contract LaunchPool is Ownable {
    // immutables
    address public launchPoolToken;
    uint public launchPoolGenesis;

    // the staking tokens for which the rewards contract has been deployed
    address[] public stakingTokens;

    // info about rewards for a particular staking token
    struct StakingRewardsInfo {
        address stakingRewards;
        uint rewardAmount;
    }

    // rewards info by staking token
    mapping(address => StakingRewardsInfo) public stakingRewardsInfoByStakingToken;

    constructor(address _rewardsToken, uint _launchPoolGenesis) Ownable() {
        require(_launchPoolGenesis >= block.timestamp, 'LaunchPool::constructor: genesis too soon');

        launchPoolToken = _rewardsToken;
        launchPoolGenesis = _launchPoolGenesis;
    }

    ///// permissioned functions

    // deploy a staking reward contract for the staking token, and store the reward amount
    // the reward will be distributed to the staking reward contract no sooner than the genesis
    function deploy(address stakingToken, uint rewardAmount) public onlyOwner {
        StakingRewardsInfo storage info = stakingRewardsInfoByStakingToken[stakingToken];
        require(info.stakingRewards == address(0), 'LaunchPool::deploy: already deployed');

        info.stakingRewards = 
        address(new LaunchStake(/*_stakeholderRewards=*/ address(this), launchPoolToken, stakingToken));
        info.rewardAmount = rewardAmount;
        stakingTokens.push(stakingToken);
    }

    ///// permissionless functions

    // call notifyRewardAmount for all staking tokens.
    function notifyRewardAmounts() public {
        require(stakingTokens.length > 0, 'LaunchPool::notifyRewardAmounts: called before any deploys');
        for (uint i = 0; i < stakingTokens.length; i++) {
            notifyRewardAmount(stakingTokens[i]);
        }
    }

    // notify reward amount for an individual staking token.
    // this is a fallback in case the notifyRewardAmounts costs too much gas to call for all contracts
    function notifyRewardAmount(address stakingToken) public {
        require(block.timestamp >= launchPoolGenesis, 'LaunchPool::notifyRewardAmount: not ready');

        StakingRewardsInfo storage info = stakingRewardsInfoByStakingToken[stakingToken];
        require(info.stakingRewards != address(0), 'LaunchPool::notifyRewardAmount: not deployed');

        if (info.rewardAmount > 0) {
            uint rewardAmount = info.rewardAmount;
            info.rewardAmount = 0;

            require(
                IERC20(launchPoolToken).transfer(info.stakingRewards, rewardAmount),
                'LaunchPool::notifyRewardAmount: transfer failed'
            );
            LaunchStake(info.stakingRewards).notifyRewardAmount(rewardAmount);
        }
    }
}