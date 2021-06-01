// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LaunchPoolTracker is Ownable {

       mapping(address => bool) private _allowedTokenAddresses;
    // Tokens to stake. We will upgrade this later.

    uint256 private _curPoolId; // count of pools in the array and map
    mapping(uint256 => LaunchPool) public poolsById;
    uint256[] public poolIds;

    enum LaunchPoolTrackerStatus {open, closed}
    LaunchPoolTrackerStatus status;
    StakeVault _stakeVault; //_stakeVault = StakeVault(stakeVaultAddress)

}