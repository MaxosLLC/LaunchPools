// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DealTracker.sol";
import "./interfaces/IERC20Minimal.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakeVault is Ownable {
    struct Stake { 
        uint128 id;
        address staker;
        address token;
        uint128 amount;
        uint128 poolId;
        bool isClaimed;
    }

    DealTracker private _poolTrackerContract;
    uint128 private _curStakeId = 0;
    mapping(uint256 => Stake) public stakes;
    mapping(address => uint256[]) public stakesByInvestor; // holds an array of stakes for one investor. Each element of the array is an ID for the stakes array

    enum PoolStatus {AcceptingStakes, OfferPosted, Delivering, Claiming, Closed}

    struct PoolInfo {
        address sponsor;
        PoolStatus status;
        uint256 dateClaiming;
    }

    mapping(uint256 => PoolInfo) poolsById;
    mapping(uint256 => bool) pool_emergency;    //emergency by pool

    event PoolOpened(uint, address);
    event PoolClosed(uint, address);
    event StakeAdded(uint, uint, address, uint, address);
    event Unstake(uint, address);
    event EmptyPool(address, uint);
    event StakeCommitted(uint, bool, address);
    event StakesUncommitted(uint, address);
    event ClaimStatus(uint, address, PoolStatus);
    event Claim(uint, address);

    function setPoolContract(DealTracker poolTrackerContract_) external onlyOwner{
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

    function updatePoolStatus (uint256 poolId, uint256 status) external {
        PoolInfo storage pi = poolsById[poolId];
        pi.status = PoolStatus(status);
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
        require(!(isDeliveringStatus(poolId) || isClaimingStatus(poolId) || isClosedStatus(poolId)), "Pool has expired"); 
        address staker = msg.sender;
        _curStakeId = _curStakeId + 1;

        Stake storage st = stakes[_curStakeId];
        st.id = _curStakeId;
        st.staker = staker;
        st.token = token;
        st.amount = amount;
        st.poolId = poolId;
        st.isClaimed = false;

        stakesByInvestor[staker].push(_curStakeId);

        _poolTrackerContract.addStake(poolId, _curStakeId);

        IERC20Minimal(token).transferFrom(staker, address(this), amount);

        emit StakeAdded(poolId, _curStakeId, token, amount, msg.sender);
    }

    /// @notice Un-Stake
    function unStake (uint256 stakeId) external {
        PoolInfo storage poolInfo = poolsById[stakes[stakeId].poolId];
        require(!isClaimingStatus(stakes[stakeId].poolId) || (isClaimingStatus(stakes[stakeId].poolId) && block.timestamp > poolInfo.dateClaiming + 7 days) , "Pool is in Delivering or Claming Status"); 
        require(msg.sender == stakes[stakeId].staker, "Must be the staker to call this");      //Omited in emergency
        require(stakes[stakeId].isClaimed, "This stake is already claimed");
        _sendBack(stakeId); 

        emit Unstake(stakeId, msg.sender);
    }

    /// @notice Any users can empty pool to send back all stakes in the pool after pool is closed
    function emptyPool(uint256 poolId) external {
        PoolInfo storage poolInfo = poolsById[poolId];
        require(poolInfo.status == PoolStatus.Closed, "Owner must declare emergency for this pool");
        uint256[] memory _stakes = _poolTrackerContract.getStakes(poolId);
        for (uint256 i = 0; i < _stakes.length; i++) {
            _sendBack(_stakes[i]);
        }

        emit EmptyPool(msg.sender, poolId);
    }

    function getCommittedAmount(uint256 stakeId) external view returns(uint256) {
        return stakes[stakeId].amount;
    }

    // must be called by the sponsor address
    // The sponsor claims committed stakes in a pool. This checks to see if the admin has put the pool in “claiming” state. It sends or allows all stakes to the sponsor address. It closes the pool (sending back all uncommitted stakes)
    function claim (uint256 poolId) external {
        PoolInfo storage poolInfo = poolsById[poolId];
        require(msg.sender == poolInfo.sponsor, "Claim should be called by sponsor.");
        require(poolInfo.status == PoolStatus.Claiming, "Claim should be called when the pool is in claiming state.");
         uint256[] memory _stakes = _poolTrackerContract.getStakes(poolId);
        for(uint256 i = 0; i < _stakes.length; i ++) {
            if(!stakes[_stakes[i]].isClaimed) {
                IERC20Minimal(stakes[_stakes[i]].token).transfer(poolInfo.sponsor, stakes[_stakes[i]].amount);
                stakes[_stakes[i]].isClaimed = true;
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

    
    /// @notice Checking Pool Status functions

    function isDeliveringStatus(uint256 poolId) private view returns(bool) {
        PoolInfo storage pi = poolsById[poolId];
        return (pi.status == PoolStatus.Delivering);
    }

    function isClaimingStatus(uint256 poolId) private view returns(bool) {
        PoolInfo storage pi = poolsById[poolId];
        return (pi.status == PoolStatus.Claiming);
    }

    function isClosedStatus(uint256 poolId) private view returns(bool) {
        PoolInfo storage pi = poolsById[poolId];
        return (pi.status == PoolStatus.Closed);
    }

    /// @notice set pool status
    function setPoolStatus(uint256 poolId, uint256 status) public {
        PoolInfo storage pi = poolsById[poolId];
        require(pi.status != PoolStatus.Closed, "Closed status cannot be updated");
        if(PoolStatus(status) == PoolStatus.Claiming) {
            require(msg.sender == owner(), "Claiming status cannot be set in this function");
            pi.dateClaiming = block.timestamp;
        }
        pi.status = PoolStatus(status);
    }
}





