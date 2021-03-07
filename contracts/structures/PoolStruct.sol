// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "./PoolReward.sol";
import "./PoolFund.sol";
import "./PoolWallet.sol";

struct PoolStructure {
    bytes32 pool_indice; // hash for pool
    bytes32 pool_name; // Full name of the Pool
    address input_asset; // erc20 token from the input asset of the pool
    address output_asset; // erc20 token from the output asset for the pool (rewards)
    uint256 start_date; // Date on which the Peet pool will start
    uint256 end_date; // Date on which the Peet pool end, or start again with a renewal state

    bool pool_active; // Current pool state, available and activity

    PoolRewards rewards_pool; // Details about bonus given from this pool
    PoolFunds funds_pool; // Condition for this pool participation

    mapping(address => PoolWallet) _wallets;
    uint256 total_amount_input_pooled;
}