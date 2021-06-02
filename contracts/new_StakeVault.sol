// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract StakeVault is Ownable {

    struct Stake {
        
        uint256 id;
        address staker;
        address token;
        uint256 amount;
        uint256 poolId;
        bool isCommitted;
    }

    address private _poolTrackerContract;
    mapping(uint256 => Stake) _stakes;
    mapping(address => uint256[]) _stakesByAccount; // holds an array of stakes for one investor. Each element of the array is an ID for the _stakes array

    struct PoolInfo {
        address sponsor;
        // PoolStatus status;
        uint256 expiration;
    }

    mapping(uint256 => PoolInfo) poolsById;

    // Called  by a launchPool. Adds to the poolsById mapping in the stakeVault. Passes the id from the poolIds array. 
    // Sets the sponsor and the expiration date and sets the status to “Staking”
    function addPool (uint256 poolId, address sponsor, uint256 expiration) public {}

    // Can be called by the admin or the sponsor. Can be called by any address after the expiration date. Sends back all stakes. 
    // A closed pool only allows unStake actions
    function closePool (uint256 poolId) public {}
    
    // Make a stake structure
    // get the staker from the sender
    // Add this stake to a map that uses the staker address as a key
    // Generate an ID so we can look this up
    // Also call the launchpool to add this stake to its list, with the ID
    function addStake (uint256 poolId, address token, uint256 amount) public {}
    
    function unStake (uint256 stakeId) public {}
    
    function commitStake (uint256  stakeId) public {}
    
    // the Launchpool calls this if the offer does not reach a minimum value
    function unCommitStakes (uint256 poolId) public {}
    
    // get all of the stakes that are owned by a user address. We can use this list to show an investor their pools or stakes
    // We also need an ID that we can send to the array of stakes in a launchpool
    function getInvestorStakes (uint256 investorID) public {}
    
    // Put the pool into “Claim” status. The administrator can do this after checking delivery
    function setPoolClaimStatus (uint256 poolId) public {}
    
    // must be called by the sponsor address
    // The sponsor claims committed stakes in a pool. This checks to see if the admin has put the pool in “claiming” state. It sends or allows all stakes to the sponsor address. It closes the pool (sending back all uncommitted stakes) 
    function claim (uint256 poolId) public {}


}