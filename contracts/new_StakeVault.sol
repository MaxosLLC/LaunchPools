// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./new_LaunchPoolTracker.sol";
import "./interfaces/IERC20Minimal.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakeVault is Ownable {
    struct Stake {
        address staker;
        address token;
        uint128 amount;
        uint128 poolId;
        bool isCommitted;
    }

    LaunchPoolTracker private _poolTrackerContract;
    uint256 private _curStakeId;
    mapping(uint256 => Stake) _stakes;
    mapping(address => uint256[]) public stakesByInvestor; // holds an array of stakes for one investor. Each element of the array is an ID for the _stakes array

    enum PoolStatus {AcceptingStakes, AcceptingCommitments, Delivering, Claiming, Closed}

    struct PoolInfo {
        address sponsor;
        PoolStatus status;
        uint256 expiration;
    }

    mapping(uint256 => PoolInfo) poolsById;
    mapping(uint256 => bool) pool_emergency;    //emergency by pool

    event PoolOpen(uint, address, uint);

    function setPoolContract(LaunchPoolTracker poolTrackerContract_) external onlyOwner{
        _poolTrackerContract = poolTrackerContract_;
    }

    // Called  by a launchPool. Adds to the poolsById mapping in the stakeVault. Passes the id from the poolIds array.
    // Sets the sponsor and the expiration date and sets the status to “Staking”
    // The sponsor becomes the owner
    function addPool (uint256 poolId, address sponsor, uint256 expiration) external {
   
        PoolInfo storage pi = poolsById[poolId];    //Storage is appropriate
        pi.sponsor = sponsor;
        pi.status = PoolStatus.AcceptingStakes;
        pi.expiration = expiration;

        emit PoolOpen(poolId, sponsor, expiration);
    }

    // Can be called by the admin or the sponsor. Can be called by any address after the expiration date. Sends back all stakes.
    // A closed pool only allows unStake actions
    function closePool (uint256 poolId) external{
        PoolInfo storage poolInfo = poolsById[poolId];

        require(
            (msg.sender == poolInfo.sponsor) || 
            (msg.sender == owner()) ||
            (poolInfo.expiration <= block.timestamp), 
            
            "ClosePool is not allowed for this case.");

        poolInfo.status = PoolStatus.Closed;
        
        for(uint256 i = 0 ; i < _curStakeId ; i ++) {
            if(_stakes[i].poolId == poolId){
                _sendBack(i);
            }
        }
    }

    // Make a stake structure
    // get the staker from the sender
    // Add this stake to a map that uses the staker address as a key
    // Generate an ID so we can look this up
    // Also call the launchpool to add this stake to its list, with the ID
    function addStake(
        uint256 poolId,
        address token,
        uint256 amount
    ) external returns (uint256)
    {
        address staker = msg.sender;
        uint256 _currStakeId = _curStakeId + 1;

        Stake storage st = _stakes[_currStakeId];    //Appropriate storage use
        st.id = _currStakeId;
        st.staker = staker;
        st.token = token;
        st.amount = amount;
        st.poolId = poolId;
        st.isCommitted = false;

        stakesByInvestor[staker].push(_currStakeId);

        _poolTrackerContract.addStake(_currStakeId, poolId);

        IERC20Minimal(token).transferFrom(staker, address(this), amount);

        return _currStakeId;
    }

    /// @notice Un-Stake
    function unStake (uint256 stakeId) external{
        require(!_stakes[stakeId].isCommitted, "cannot unstake commited stake");
        require(msg.sender == _stakes[stakeId].staker, "Must be the staker to call this");      //Omited in emergency
        _sendBack(stakeId); 
    }

    /// @notice emergency unstake must be toggled on by owner. Allows anyone to unstake commited stakes
    function emergencyUnstake(uint256 stakeId) external{
        require(pool_emergency[_stakes[stakeId].poolId], "Owner must declare emergency for this pool");
        _sendBack(stakeId);
    }

    /// @notice owner can declare a pool in emergency
    function declareEmergency(uint256 poolId) external onlyOwner{
        require(pool_emergency[poolId] != true, "already in emergency state");
        pool_emergency[poolId] = true;
    }

    /// @notice owner can declare a pool in emergency
    function removeEmergency(uint256 poolId) external onlyOwner{
        require(pool_emergency[poolId] != false, "Pool not in emergency state");
        pool_emergency[poolId] = false;
    }

    function commitStake (uint256 stakeId) external {
        require(!_stakes[stakeId].isCommitted, "Stake is already committed");
        require(_stakes[stakeId].staker == msg.sender, "You are not the owner of this stake");
        _stakes[stakeId].isCommitted = true;
    }

    // the Launchpool calls this if the offer does not reach a minimum value
    function unCommitStakes (uint256 poolId) external{
    require(
        msg.sender == owner() ||
        msg.sender == address(_poolTrackerContract),            // CONFIRM this function is called by pool tracker
        "Only owner or pool tracker contract can call this function"        
    );
        for(uint256 i = 0 ; i < _curStakeId ; i ++) {
            if(_stakes[i].poolId == poolId){
                _stakes[i].isCommitted = false;
            }
        }
    }

    // Put the pool into “Claim” status. The administrator can do this after checking delivery
    function setPoolClaimStatus(uint256 poolId) external onlyOwner {
        PoolInfo storage poolInfo = poolsById[poolId];
        require(poolInfo.status == PoolStatus.Delivering, "LaunchPool is not delivering status.");
        
        poolInfo.status = PoolStatus.Claiming;
    }

    // must be called by the sponsor address
    // The sponsor claims committed stakes in a pool. This checks to see if the admin has put the pool in “claiming” state. It sends or allows all stakes to the sponsor address. It closes the pool (sending back all uncommitted stakes)
    function claim (uint256 poolId) external{
        require(msg.sender == poolInfo.sponsor, "Claim should be called by sponsor.");
        require(poolInfo.status == PoolStatus.Claiming, "Claim should be called when the pool is in claiming state.");
        PoolInfo storage poolInfo = poolsById[poolId];
        
        for(uint256 i = 0 ; i < _curStakeId ; i ++) {
            if(_stakes[i].poolId == poolId){
                if(_stakes[i].isCommitted == true) {
                    IERC20Minimal(_stakes[i].token).transfer(poolInfo.sponsor, _stakes[i].amount);
                }
                else {
                    IERC20Minimal(_stakes[i].token).transfer(_stakes[i].staker,  _stakes[i].amount);
                }
            }
        }
        poolInfo.status = PoolStatus.Closed;
    }

    /// @notice send back tokens to investor or investors
    function _sendBack (uint256 stakeId) private {
        //withdraw Stake
        uint temp = _stakes[stakeId].amount;
        _stakes[stakeId].amount = 0;
        IERC20Minimal(_stakes[stakeId].token).transfer( _stakes[stakeId].staker,  temp);
    }

}


