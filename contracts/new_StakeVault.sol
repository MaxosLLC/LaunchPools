// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./interfaces/IERC20Minimal.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract StakeVault is Ownable {
    enum PoolStatus {AcceptingStakes, AcceptingCommitments, Funded, Closed}

    struct Stake {
        
        uint256 id;
        address staker;
        address token;
        uint256 amount;
        uint256 poolId;
        bool isCommitted;
    }

    address private _poolTrackerContract;
    uint256 private _curStakeId;
    mapping(uint256 => Stake) public _stakes;
    mapping(address => uint256[]) public _stakesByAccount; // holds an array of stakes for one investor. Each element of the array is an ID for the _stakes array

    struct PoolInfo {
        address sponsor;
        // PoolStatus status;
        uint256 expiration;
    }

    mapping(uint256 => PoolInfo) poolsById;

    function _atStage(uint256 poolId, PoolStatus stage_) private view returns (bool) {        
        LaunchPool storage lp = _poolTrackerContract.poolsById[poolId];
        return lp.stage == stage_;
    }

    modifier isTokenAllowed(address _tokenAddr) {
        require(
            _poolTrackerContract._allowedTokenAddresses[_tokenAddr],
            "Cannot deposit that token"
        );
        _;
    }

    modifier isPoolOpen(uint256 poolId) {
        LaunchPool storage lp = _poolTrackerContract.poolsById[poolId];

        if (block.timestamp > lp.poolExpiry.startTime + lp.poolExpiry.duration) {
            lp.stage = PoolStatus.Closed;
        }

        require(!_atStage(poolId, PoolStatus.Closed), "LaunchPool is closed");
        _;
    }

    modifier canStake(uint256 poolId) {
        require(
            _atStage(poolId, PoolStatus.AcceptingStakes) ||
                _atStage(poolId, PoolStatus.AcceptingCommitments),
            "Not in desired stage"
        );
        _;
    }

    modifier canCommit(uint256 poolId) {
        require(
            _atStage(poolId, PoolStatus.AcceptingCommitments),
            "Not in either of desired stages"
        );
        _;
    }

    modifier senderOwnsStake(uint256 stakeId) {
        Stake memory st = _stakes[stakeId];
        require(
            st.staker == msg.sender,
            "Account not authorized to unstake"
        );
        _;
    }

    modifier isOfferOpen(uint256 poolId) {
        LaunchPool storage lp = _poolTrackerContract.poolsById[poolId];

        require(
            (block.timestamp <= lp.offerExpiry.startTime + lp.offerExpiry.duration) &&
                _atStage(poolId, PoolStatus.AcceptingCommitments),
            "Offer is closed"
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
        isPoolOpen(poolId)
        isTokenAllowed(token)
        canStake(poolId) 
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

        _poolTrackerContract.addStake(poolId, _currStakeId);

        // If the transfer fails, we revert and don't record the amount.
        require(
            IERC20Minimal(token).transferFrom(staker, address(this), amount),
            "Did not get the moneys"
        );
    }
    
    // @notice Un-Stake
    function unStake (uint256 stakeId) public 
        isPoolOpen(poolId)
        senderOwnsStake(poolId, stakeId)
        canStake(poolId) 
    {
        require(!_stakes[stakeId].isCommitted, "cannot unstake commited stake");
        
        Stake storage st = _stakes[stakeId];
        address staker = st.staker;

        delete _stakes[stakeId];

        // @notice find Stake in staker's stake list
        uint256 length = _stakesByAccount[staker].length;
        uint256 stakeIdx = -1;
        for(uint256 i = 0 ; i < length ; i ++) {
            if(_stakesByAccount[staker][i] == stakeId) {
                stakeIdx = int256(i);
                break;
            }
        }
        assert(stakeIdx != -1);

        // @notice remove Stake in staker's stake list
        uint256[] memory accountStakes = _stakesByAccount[staker];
        uint256 lastIdx = accountStakes.length - 1;
        if(stakeIdx != lastIdx) {
            _stakesByAccount[staker][stakeIdx] = _stakesByAccount[staker][lastIdx];
        }
        _stakesByAccount[staker].pop();

        // @notice withdraw Stake
        require(
            IERC20Minimal(st.token).transfer(st.staker, st.amount), "Could not send the moneys"
        );
    }
    
    function commitStake (uint256 stakeId) public 
        isPoolOpen(poolId)
        isOfferOpen(poolId)
        canCommit(poolId)
        senderOwnsStake(poolId, stakeId)
    {
        require(!_stakes[stakeId].isCommitted, "Stake is already committed");
        require(stakes[stakeId].staker != address(0), "Stake doesn't exist");

        _stakes[stakeId].isCommitted = true;
    }
    
    function unCommitStakes (uint256 poolId) public 
        isPoolOpen(poolId)
    {
        uint256 length = _stakes.length;
        for(uint256 i = 0 ; i < length ; i ++) {
            if(_stakes[i].poolId == poolId){
                _stakes[i].isCommitted = false;
            }
        }
    }
    
    function getInvestorStakes (uint256 investorID) public {}
    
    function setPoolClaimStatus (uint256 poolId) public {}
    
    function claim (uint256 poolId) public {}


}