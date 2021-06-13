// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./new_LaunchPoolTracker.sol";
import "./interfaces/IERC20Minimal.sol";
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
    
    address private _admin;

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
    
    function setPoolContract(LaunchPoolTracker poolTrackerContract_) public {
        _poolTrackerContract = poolTrackerContract_;
    }

    // Called  by a launchPool. Adds to the poolsById mapping in the stakeVault. Passes the id from the poolIds array.
    // Sets the sponsor and the expiration date and sets the status to “Staking”
    // The sponsor becomes the owner
    function addPool (uint256 poolId, address sponsor, uint256 expiration) public {

        PoolInfo storage pi = poolsById[poolId];
        pi.sponsor = sponsor;
        pi.status = PoolStatus.AcceptingStakes;
        pi.expiration = expiration;


        //TODO add event notifying that the pool is open
    }

    // Can be called by the admin or the sponsor. Can be called by any address after the expiration date. Sends back all stakes.
    // A closed pool only allows unStake actions
    function closePool (uint256 poolId) public {
        PoolInfo storage poolInfo = poolsById[poolId];

        require(
            (msg.sender == poolInfo.sponsor) || 
            (msg.sender == _admin) || 
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
    ) public returns (uint256)
    {
        require(
            _poolTrackerContract.tokenAllowed(token) == true,
            "Token is not allowed to stake"
        );

        address staker = msg.sender;
        uint256 _currStakeId = ++_curStakeId;

        Stake storage st = _stakes[_currStakeId];
        st.id = _currStakeId;
        st.staker = staker;
        st.token = token;
        st.amount = amount;
        st.poolId = poolId;
        st.isCommitted = false;

        stakesByInvestor[staker].push(_currStakeId);

        _poolTrackerContract.addStake(_currStakeId, poolId);

        // If the transfer fails, we revert and don't record the amount.
        require(
            IERC20Minimal(token).transferFrom(staker, address(this), amount),
            "Failed to transfer tokens"
        );

        return _currStakeId;
    }

    // @notice send back tokens to investor or investors
    function _sendBack (uint256 stakeId) private {
        // @notice withdraw Stake
        require(
            IERC20Minimal(_stakes[stakeId].token).transfer( _stakes[stakeId].staker,  _stakes[stakeId].amount), "Failed to return tokens to the investor"
        );
    }

    // @notice Un-Stake
    function unStake (uint256 stakeId) public {
        require(!_stakes[stakeId].isCommitted, "cannot unstake commited stake");
        
        _sendBack(stakeId);

        _stakes[stakeId].amount = 0;
    }
    
    // @notice commit already staked stake
    function commitStake (uint256 stakeId) public {
        require(!_stakes[stakeId].isCommitted, "Stake is already committed");
        _stakes[stakeId].isCommitted = true;
    }

    // the Launchpool calls this if the offer does not reach a minimum value
    function unCommitStakes (uint256 poolId) public 
    {
        for(uint256 i = 0 ; i < _curStakeId ; i ++) {
            if(_stakes[i].poolId == poolId){
                _stakes[i].isCommitted = false;
            }
        }
    }

    // get all of the stakes that are owned by a user address. We can use this list to show an investor their pools or stakes
    // We also need an ID that we can send to the array of stakes in a launchpool
    function getInvestorStakes(address investorID) public view returns (uint256[] memory){
        return stakesByInvestor[investorID];
    }

    // Put the pool into “Claim” status. The administrator can do this after checking delivery
    function setPoolClaimStatus(uint256 poolId) public onlyOwner {
        PoolInfo storage poolInfo = poolsById[poolId];
        require(poolInfo.status == PoolStatus.Delivering, "LaunchPool is not delivering status.");
        
        poolInfo.status = PoolStatus.Claiming;
    }

    // must be called by the sponsor address
    // The sponsor claims committed stakes in a pool. This checks to see if the admin has put the pool in “claiming” state. It sends or allows all stakes to the sponsor address. It closes the pool (sending back all uncommitted stakes)
    function claim (uint256 poolId) public {
        PoolInfo storage poolInfo = poolsById[poolId];
        require(msg.sender == poolInfo.sponsor, "Claim should be called by sponsor.");
        require(poolInfo.status == PoolStatus.Claiming, "Claim should be called when the pool is in claiming state.");
        
        for(uint256 i = 0 ; i < _curStakeId ; i ++) {
            if(_stakes[i].poolId == poolId){
                if(_stakes[i].isCommitted == true) {
                    require(
                        IERC20Minimal(_stakes[i].token).transfer(poolInfo.sponsor, _stakes[i].amount),
                        "Failed to transfer tokens"
                    );
                }
                else {
                    require(
                        IERC20Minimal(_stakes[i].token).transfer(_stakes[i].staker,  _stakes[i].amount), "Failed to return tokens to the investor"
                    );
                }
            }
        }
        poolInfo.status = PoolStatus.Closed;
    }
}
