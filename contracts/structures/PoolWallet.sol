// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

struct PoolWallet {
    uint256[] input_asset_amount;
    uint256[] start_date_pooled;
    uint256 index;
}