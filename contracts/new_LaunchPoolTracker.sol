// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "./new_StakeVault.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LaunchPoolTracker is Ownable {

    mapping(address => bool) private _allowedTokenAddresses;
    // Tokens to stake. We will upgrade this later.

    bool private _isTrackerClosed; // is tracker open or closed

    uint256 private _curPoolId = 0; // count of pools in the array and map
    mapping(uint256 => LaunchPool) public poolsById;
    uint256[] public poolIds;

    enum PoolStatus {AcceptingStakes, AcceptingCommitments, Delivering, Claiming, Closed}

    struct OfferBounds {
        uint256 minimum;
        uint256 maximum;
    }

    struct Offer {
        OfferBounds bounds;
        string url;
    }

    struct ExpiryData {
        uint256 startTime;
        uint256 duration;
    }

    struct LaunchPool {
        string name;
        address sponsor;
        PoolStatus status;
        ExpiryData poolExpiry;
        ExpiryData offerExpiry;
        uint256[] stakes;
        Offer offer;
        uint256 totalCommittedAmount;
    }    

    StakeVault _stakeVault;

    event NewOffer(uint, address);
    event UpdateOffer(uint, address);
    event OfferCancelled(uint, address);
    event OfferEnded(uint, address);
    event PoolClosed(uint, address);

    /// @notice creates a new LaunchPoolTracker.
    /// @dev up to 3 tokens are allowed to be staked.
    constructor(address[] memory allowedAddresses_, StakeVault stakeVault_) {
        require(
            allowedAddresses_.length >= 1,
            "There must be at least 1"
        );
        
        for(uint256 i = 0 ; i < allowedAddresses_.length ; i ++) {
            _allowedTokenAddresses[allowedAddresses_[i]] = true;
        }

       _stakeVault = stakeVault_;
    }

    /* Modifers */

    // @notice check the launchPool is not closed and not expired
    modifier isPoolOpen(uint256 poolId) {
        LaunchPool storage lp = poolsById[poolId];
        if (block.timestamp > lp.poolExpiry.startTime + lp.poolExpiry.duration) {
            lp.status = PoolStatus.Closed;
        }
        require(!_atStatus(poolId, PoolStatus.Closed), "LaunchPool is closed");
        _;
    }

    // @notice check launchPoolTracker is open
    modifier isTrackerOpen () {
        require(
            _isTrackerClosed == false,
            "LaunchPoolTracker is closed."
        );
        _;
    }

    // @notice check the poolId is not out of range
    modifier isValidPoolId(uint256 poolId) {
        require(poolId <= _curPoolId, "LaunchPool Id is out of range.");
        _;
    }

    // @notice check the token is allowed
    function tokenAllowed(address token) public view returns (bool) {
        return _allowedTokenAddresses[token];
    }

    function addTokenAllowness(address token) public onlyOwner {
        _allowedTokenAddresses[token] = true;
    }

    // @notice add a pool and call addPool() in StakeVault contract
    function addPool(
        string memory _poolName,
        uint256 poolValidDuration_,
        uint256 offerValidDuration_,
        uint256 minOfferAmount_,
        uint256 maxOfferAmount_) public {

        _curPoolId = _curPoolId + 1;
        LaunchPool storage lp = poolsById[_curPoolId];

        lp.name = _poolName;
        lp.status = PoolStatus.AcceptingStakes;
        lp.poolExpiry.startTime = block.timestamp;
        lp.poolExpiry.duration = poolValidDuration_;

        lp.offerExpiry.duration = offerValidDuration_;

        lp.offer.bounds.minimum = minOfferAmount_;
        lp.offer.bounds.maximum = maxOfferAmount_;

        lp.sponsor = msg.sender;

        poolIds.push(_curPoolId);

        _stakeVault.addPool(_curPoolId, msg.sender, block.timestamp + poolValidDuration_);
    }

    function updatePoolStatus(uint256 poolId, uint256 status) public onlyOwner {
        LaunchPool storage lp = poolsById[poolId];
        lp.status = PoolStatus(status);

        _stakeVault.updatePoolStatus(poolId, status);
    }

    // @notice return the launchpool status is same as expected
    function _atStatus(uint256 poolId, PoolStatus status) private view returns (bool) {
        LaunchPool storage lp = poolsById[poolId];
        return lp.status == status;
    }

    // @notice Check the launchPool offer is expired or not
    function _isAfterOfferClose(uint256 poolId) private view returns (bool) {
        LaunchPool storage lp = poolsById[poolId];
        return block.timestamp >= lp.offerExpiry.startTime + lp.offerExpiry.duration;
    }

    // @notice Check the launchPool offer is able to claim or not
    function canClaimOffer(uint256 poolId) public view returns (bool) {
        LaunchPool storage lp = poolsById[poolId];
        return _isAfterOfferClose(poolId) && getTotalCommittedAmount(poolId) >= lp.offer.bounds.minimum;
    }
    
    
    // @notice return poolIds
    function getPoolIds() public view returns (uint256 [] memory) {
        return poolIds;
    }

    // called from the stakeVault. Adds to a list of the stakes in a pool, in stake order
    function addStake (uint256 poolId, uint256 stakeId) public isValidPoolId(poolId){
        LaunchPool storage lp = poolsById[poolId];
        lp.stakes.push(stakeId);
    }

    // Get a list of stakes for the pool. This will be used by users, and also by the stakeVault
    // returns a list of IDs (figure out how to identify stakes in the stakevault. We know the pool)
    function getStakes (uint256 poolId) public view returns(uint256 [] memory) {
        LaunchPool storage lp = poolsById[poolId];
        return lp.stakes;
    }
    
    // Put in committing status. Save a link to the offer
    // url contains the site that the description of the offer made by the sponsor
    function newOffer (uint256 poolId, string memory url, uint256 duration) public isValidPoolId(poolId) isPoolOpen(poolId) {
        LaunchPool storage lp = poolsById[poolId];
        lp.status = PoolStatus.AcceptingCommitments;
        lp.offerExpiry.startTime = block.timestamp;
        lp.offerExpiry.duration = duration;
        lp.offer.url = url;
        _stakeVault.updatePoolStatus(poolId, uint256(lp.status));
        emit NewOffer(poolId, msg.sender);
    }
    
    // put back in staking status.
    function cancelOffer (uint256 poolId) public onlyOwner isValidPoolId(poolId) {
        LaunchPool storage lp = poolsById[poolId];
        lp.status = PoolStatus.AcceptingStakes;
        _stakeVault.updatePoolStatus(poolId, uint256(lp.status));
        emit OfferCancelled(poolId, msg.sender);
    }
    
    // runs the logic for an offer that fails to reach minimum commitment, or succeeds and goes to Delivering status
    function endOffer (uint256 poolId) public onlyOwner isValidPoolId(poolId) {
        LaunchPool storage lp = poolsById[poolId];
        if(canClaimOffer(poolId)) {
            lp.status = PoolStatus.Delivering;
        }
        if(!canClaimOffer(poolId)) {
            lp.status = PoolStatus.AcceptingStakes;
            _stakeVault.unCommitStakes(poolId);
        }

        _stakeVault.updatePoolStatus(poolId, uint256(lp.status));

        emit OfferEnded(poolId, msg.sender);
    }

    function updateOffer (uint256 poolId, string memory url, uint256 duration) public onlyOwner isValidPoolId(poolId) {
        LaunchPool storage lp = poolsById[poolId];
        lp.offerExpiry.startTime = block.timestamp;
        lp.offerExpiry.duration = duration;
        lp.offer.url = url;

        emit UpdateOffer(poolId, msg.sender);
    }

    function getTotalCommittedAmount(uint256 poolId) public view returns(uint256) {
        LaunchPool storage lp = poolsById[poolId];
        uint256 totalCommittedAmount = 0;
        for(uint i = 0; i < lp.stakes.length; i++) {
            totalCommittedAmount += _stakeVault.getCommittedAmount(lp.stakes[i]);
        }
        return totalCommittedAmount;
    }

    // OPTIONAL IN THIS VERSION. calculates new dollar values for stakes. 
    // Eventually, we will save these values at the point were we go to “deliver” the investment amount based on the dollar value of a committed stake.
    function setValues () public onlyOwner {}
    
    // OPTIONAL IN THIS VERSION. We need a way to report the list of committed stakes, with the value of the committed stakes and the investor. 
    //This forms a list of the investments that need to be delivered. It is basically a “setValues” followed by getStakes.
    function getInvestmentValues () public {}
    
    // calls stakeVault closePool, sets status to closed
    function closePool (uint256 poolId) public isValidPoolId(poolId) {
        _stakeVault.closePool(poolId);
        LaunchPool storage lp = poolsById[poolId];
        lp.status = PoolStatus.Closed;
        _stakeVault.updatePoolStatus(poolId, uint256(lp.status));
        emit PoolClosed(poolId, msg.sender);
    }

    // calls closePool for all LaunchPools, sets _isTrackerClosed to true
    function closeTracker () public {
        for(uint256 i = 0 ; i < _curPoolId ; i ++) {
            closePool(poolIds[i]);
        }

        _isTrackerClosed = true;
    }
}
