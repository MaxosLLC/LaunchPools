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

    function addPool (uint256 poolId, address sponsor, uint256 expiration) public {}

    function closePool (uint256 poolId) public {}
    
    function addStake (uint256 poolId, address token, uint256 amount) public {}
    
    function unStake (uint256 stakeId) public {}
    
    function commitStake (uint256  stakeId) public {}
    
    function unCommitStakes (uint256 poolId) public {}
    
    function getInvestorStakes (uint256 investorID) public {}
    
    function setPoolClaimStatus (uint256 poolId) public {}
    
    function claim (uint256 poolId) public {}


}