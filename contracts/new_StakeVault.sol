// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./interfaces/IERC20Minimal.sol";
import "./new_LaunchPoolTracker.sol";
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

    LaunchPoolTracker private _poolTrackerContract;
    mapping(uint256 => Stake) _stakes;
    mapping(address => uint256[]) _stakesByAccount; // holds an array of stakes for one investor. Each element of the array is an ID for the _stakes array

    enum PoolStatus {AcceptingStakes, AcceptingCommitments, Funded, Closed}

    struct PoolInfo {
        address sponsor;
        PoolStatus status;
        uint256 expiration;
    }

    mapping(uint256 => PoolInfo) poolsById;
    uint256 private _curStakeId;

    // Called  by a launchPool. Adds to the poolsById mapping in the stakeVault. Passes the id from the poolIds array. 
    // Sets the sponsor and the expiration date and sets the status to “Staking”
    // A user creates a launchpool and becomes a sponsor
    function addPool (uint256 poolId, address sponsor, uint256 expiration) public {

        PoolInfo storage pi = poolsById[poolId];
        pi.sponsor = sponsor;
        pi.status = PoolStatus.AcceptingStakes;
        pi.expiration = expiration;


        //TODO add event notifying that the pool is open
    }

    function setPoolTracker (LaunchPoolTracker launchPoolTracker) public {
        _poolTrackerContract = launchPoolTracker;
    }

    // Can be called by the admin or the sponsor. Can be called by any address after the expiration date. Sends back all stakes. 
    // A closed pool only allows unStake actions
    function closePool (uint256 poolId) public {}
    
    // Make a stake structure
    // get the staker from the sender
    // Add this stake to a map that uses the staker address as a key
    // Generate an ID so we can look this up
    // Also call the launchpool to add this stake to its list, with the ID
    function addStake (uint256 poolId, address token, uint256 amount) public returns (uint256)
    {
        address staker = msg.sender;
        uint256 _currStakeId = ++_curStakeId;

        Stake storage st = _stakes[_currStakeId];
        st.id = _currStakeId;
        st.staker = staker;
        st.token = token;
        st.amount = amount;
        st.poolId = poolId;
        st.isCommitted = false;

        _stakesByAccount[staker].push(_currStakeId);

        _poolTrackerContract.addStake(_currStakeId);

        // If the transfer fails, we revert and don't record the amount.
        require(
            IERC20Minimal(token).transferFrom(staker, address(this), amount),
            "Did not get the moneys"
        );

        return _currStakeId;
    }
    
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