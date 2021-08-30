// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./new_LaunchPoolTracker.sol";
import "./interfaces/IERC20Minimal.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract StakeVault is Ownable, Initializable {
    struct Stake { 
        uint128 id;
        address staker;
        address token;
        uint128 amount;
        uint128 poolId;
        bool isCommitted;
    }

    LaunchPoolTracker private _poolTrackerContract;
    uint128 private _curStakeId = 0;
    mapping(uint256 => Stake) public stakes;
    mapping(address => uint256[]) public stakesByInvestor; // holds an array of stakes for one investor. Each element of the array is an ID for the stakes array

    enum PoolStatus {AcceptingStakes, OfferPosted, OfferClosed, Delivering, Claiming, Closed}

    struct PoolInfo {
        address sponsor;
        PoolStatus status;
    }

    mapping(uint256 => PoolInfo) poolsById;
    mapping(uint256 => bool) pool_emergency;    //emergency by pool

    event PoolOpened(uint, address);
    event PoolClosed(uint, address);
    event StakeAdded(uint, uint, address, uint, address);
    event Unstake(uint, address);
    event EmergencyUnstake(uint, address);
    event Emergency(uint, bool, address);
    event StakeCommitted(uint, bool, address);
    event StakesUncommitted(uint, address);
    event ClaimStatus(uint, address, PoolStatus);
    event Claim(uint, address);

    function setPoolContract(LaunchPoolTracker poolTrackerContract_) external onlyOwner{
        _poolTrackerContract = poolTrackerContract_;
    }

    // Called  by a launchPool. Adds to the poolsById mapping in the stakeVault. Passes the id from the poolIds array.
    // Sets the sponsor and the expiration date and sets the status to “Staking”
    // The sponsor becomes the owner
    function addPool (uint256 poolId, address sponsor) external {
   
        PoolInfo storage pi = poolsById[poolId];
        pi.sponsor = sponsor;
        pi.status = PoolStatus.AcceptingStakes;

        emit PoolOpened(poolId, sponsor);
    }

    function updatePoolStatus (uint256 poolId, uint256 status) external onlyOwner{
        PoolInfo storage pi = poolsById[poolId];
        pi.status = PoolStatus(status);
    }

    // Can be called by the admin or the sponsor. Can be called by any address after the expiration date. Sends back all stakes.
    // A closed pool only allows unStake actions
    function closePool (uint256 poolId) external {
        PoolInfo storage poolInfo = poolsById[poolId];
        require((msg.sender == poolInfo.sponsor) || msg.sender == owner(), "ClosePool is not allowed for this case.");

        poolInfo.status = PoolStatus.Closed;
        
        for(uint256 i = 0 ; i < _curStakeId ; i ++) {
            if(stakes[i].poolId == poolId) {
                _sendBack(i);
                break;
            }
        }

        emit PoolClosed(poolId, msg.sender);
    }

    // Make a stake structure
    // get the staker from the sender
    // Add this stake to a map that uses the staker address as a key
    // Generate an ID so we can look this up
    // Also call the launchpool to add this stake to its list, with the ID
    function addStake(
        uint128 poolId,
        address token,
        uint128 amount
    ) external
    {
        require(_poolTrackerContract.isOfferInPeriod(poolId), "Pool has expired"); 
        address staker = msg.sender;
        _curStakeId = _curStakeId + 1;

        Stake storage st = stakes[_curStakeId];
        st.id = _curStakeId;
        st.staker = staker;
        st.token = token;
        st.amount = amount;
        st.poolId = poolId;
        st.isCommitted = false;

        stakesByInvestor[staker].push(_curStakeId);

        _poolTrackerContract.addStake(poolId, _curStakeId);

        IERC20Minimal(token).transferFrom(staker, address(this), amount);

        emit StakeAdded(poolId, _curStakeId, token, amount, msg.sender);
    }

    /// @notice Un-Stake
    function unStake (uint256 stakeId) external {
        require(!_poolTrackerContract.isDeliveringStatus(stakes[stakeId].poolId) && !_poolTrackerContract.isClaimingStatus(stakes[stakeId].poolId), "Pool is in Delivering or Claming Status"); 
        require(msg.sender == stakes[stakeId].staker, "Must be the staker to call this");      //Omited in emergency
        _sendBack(stakeId); 

        emit Unstake(stakeId, msg.sender);
    }

    /// @notice emergency unstake must be toggled on by owner. Allows anyone to unstake commited stakes
    function emergencyUnstake(uint256 stakeId) external {
        require(pool_emergency[stakes[stakeId].poolId], "Owner must declare emergency for this pool");
        _sendBack(stakeId);

        emit EmergencyUnstake(stakeId, msg.sender);
    }

    /// @notice owner can declare a pool in emergency
    function declareEmergency(uint256 poolId) external onlyOwner {
        require(pool_emergency[poolId] != true, "already in emergency state");
        pool_emergency[poolId] = true;

        emit Emergency(poolId, pool_emergency[poolId], msg.sender);
    }

    /// @notice owner can declare a pool in emergency
    function removeEmergency(uint256 poolId) external onlyOwner {
        require(pool_emergency[poolId] != false, "Pool not in emergency state");
        pool_emergency[poolId] = false;

        emit Emergency(poolId, pool_emergency[poolId], msg.sender);
    }

    function getCommittedAmount(uint256 stakeId) external view returns(uint256) {
        if(stakes[stakeId].isCommitted) {
            return stakes[stakeId].amount;
        } else {
            return 0;
        }       
    }

    function setDeliveringStatus(uint256 poolId) external onlyOwner {
        PoolInfo storage poolInfo = poolsById[poolId];
        poolInfo.status = PoolStatus.Delivering;

        emit ClaimStatus(poolId, msg.sender, poolInfo.status);
    }

    // Put the pool into “Claim” status. The administrator can do this after checking delivery
    function setPoolClaimStatus(uint256 poolId) external onlyOwner {
        PoolInfo storage poolInfo = poolsById[poolId];
        require(poolInfo.status == PoolStatus.Delivering, "LaunchPool is not delivering status.");
        
        poolInfo.status = PoolStatus.Claiming;

        emit ClaimStatus(poolId, msg.sender, poolInfo.status);
    }

    // must be called by the sponsor address
    // The sponsor claims committed stakes in a pool. This checks to see if the admin has put the pool in “claiming” state. It sends or allows all stakes to the sponsor address. It closes the pool (sending back all uncommitted stakes)
    function claim (uint256 poolId) external{
        PoolInfo storage poolInfo = poolsById[poolId];
        require(msg.sender == poolInfo.sponsor, "Claim should be called by sponsor.");
        require(poolInfo.status == PoolStatus.Claiming, "Claim should be called when the pool is in claiming state.");
        
        for(uint256 i = 0 ; i < _curStakeId ; i ++) {
            if(stakes[i].poolId == poolId) {
                if(stakes[i].isCommitted == true) {
                    IERC20Minimal(stakes[i].token).transfer(poolInfo.sponsor, stakes[i].amount);
                }
                else {
                    IERC20Minimal(stakes[i].token).transfer(stakes[i].staker, stakes[i].amount);
                }
            }
        }
        poolInfo.status = PoolStatus.Closed;

        emit Claim(poolId, msg.sender);
    }

    /// @notice send back tokens to investor or investors
    function _sendBack (uint256 stakeId) private {
        //withdraw Stake
        uint temp = stakes[stakeId].amount;
        stakes[stakeId].amount = 0;
        IERC20Minimal(stakes[stakeId].token).transfer(stakes[stakeId].staker, temp);
    }
}





