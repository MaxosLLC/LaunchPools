// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LaunchPoolTracker is Ownable {

       mapping(address => bool) public _allowedTokenAddresses;
    // Tokens to stake. We will upgrade this later.

    uint256 private _curPoolId; // count of pools in the array and map
    mapping(uint256 => LaunchPool) public poolsById;
    uint256[] public poolIds;

    enum LaunchPoolTrackerStatus {open, closed}
    LaunchPoolTrackerStatus status;
    StakeVault _stakeVault; //_stakeVault = StakeVault(stakeVaultAddress)
    
    struct LaunchPool {
        string name;
        address sponsor;
        PoolStatus stage;
        enum PoolStatus {AcceptingStakes, AcceptingCommitments, Funded, Closed}
        ExpiryData poolExpiry;
        ExpiryData offerExpiry;
        Offer offer;
        uint256[] stakes;

        // TODO: do we need these sums? Staked, committed? We can calculate dynamically
        // uint256 totalCommitments; 

    }

    function addStake (uint256 stakeId) public {}

    function getStakes (uint256 poolId) public {}
    
    function newOffer (uint256 poolId, string url) public {}
    
    function cancelOffer (uint256 poolId) public {}
    
    function endOffer (uint256 poolId) public {}
    
    function setValues () public {}
    
    function getInvestmentValues () public {}
    
    function close (uint256 poolId) public {}

}