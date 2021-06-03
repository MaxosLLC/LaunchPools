// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./interfaces/IERC20Minimal.sol";
import "./new_LaunchPoolTracker.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract StakeVault is Ownable {
    enum PoolStatus { AcceptingStakes, AcceptingCommitments, Funded, Closed}

    struct Stake {        
        uint256 id;
        address staker;
        address token;
        uint256 amount;
        uint256 poolId;
        bool isCommitted;
    }

    LaunchPoolTracker private _poolTrackerContract;
    uint256 private _curStakeId;
    mapping(uint256 => Stake) public _stakes;
    mapping(address => uint256[]) public _stakesByAccount; // holds an array of stakes for one investor. Each element of the array is an ID for the _stakes array

    struct PoolInfo {
        address sponsor;
        // PoolStatus status;
        uint256 expiration;
    }

    mapping(uint256 => PoolInfo) poolsById;

    modifier senderOwnsStake(uint256 stakeId) {
        Stake memory st = _stakes[stakeId];
        require(
            st.staker == msg.sender,
            "Account not authorized to unstake"
        );
        _;
    }

    // @notice Add PoolInfo in the position of poolId
    function addPool (uint256 poolId, address sponsor, uint256 expiration) public {
        PoolInfo storage pi = poolsById[poolId];
        pi.sponsor = sponsor;
        pi.expiration = expiration;
    }

    function closePool (uint256 poolId) public {}
    
    // @notice Add Stake 
    function addStake (uint256 poolId, address token, uint256 amount) public
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
    }
    
    // @notice Un-Stake
    function unStake (uint256 stakeId) public 
        senderOwnsStake(stakeId)
    {
        require(!_stakes[stakeId].isCommitted, "cannot unstake commited stake");
        
        // @notice withdraw Stake
        require(
            IERC20Minimal(_stakes[stakeId].token).transfer( _stakes[stakeId].staker,  _stakes[stakeId].amount), "Could not send the moneys"
        );

        _stakes[stakeId].amount = 0;
    }
    
    function commitStake (uint256 stakeId) public 
        senderOwnsStake(stakeId)
    {
        require(!_stakes[stakeId].isCommitted, "Stake is already committed");
        require(_stakes[stakeId].staker != address(0), "Stake doesn't exist");

        _stakes[stakeId].isCommitted = true;
    }
    
    function unCommitStakes (uint256 poolId) public 
    {
        for(uint256 i = 0 ; i < _curStakeId ; i ++) {
            if(_stakes[i].poolId == poolId){
                _stakes[i].isCommitted = false;
            }
        }
    }
    
    function getInvestorStakes (uint256 investorID) public {}
    
    function setPoolClaimStatus (uint256 poolId) public {}
    
    function claim (uint256 poolId) public {}


}