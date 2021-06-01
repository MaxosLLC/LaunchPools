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

    function addPool () public {}

    function closePool () public {}
    
    function addStake () public {}
    
    function unStake () public {}
    
    function commitStake () public {}
    
    function unCommitStakes () public {}
    
    function getInvestorStakes () public {}
    
    function setPoolClaimStatus () public {}
    
    function claim () public {}


}