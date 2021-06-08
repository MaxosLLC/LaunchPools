// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LaunchPoolTracker is Ownable {

    mapping(address => bool) private _allowedTokenAddresses;
    // Tokens to stake. We will upgrade this later.

    uint256 private _curPoolId; // count of pools in the array and map
    mapping(uint256 => LaunchPool) public poolsById;
    uint256[] public poolIds;

    enum PoolStatus {AcceptingStakes, AcceptingCommitments, Funded, Closed}
    
    struct OfferBounds {
        uint256 minimum;
        uint256 maximum;
    }

    struct Offer {
        OfferBounds bounds;
        string url;
    }

    struct LaunchPool {
        string name;
        address sponsor;
        PoolStatus stage;
        uint256 poolExpiry;
        uint256 offerExpiry;
        uint256[] stakes;
        Offer offer;

        // TODO: do we need these sums? Staked, committed? We can calculate dynamically
        // uint256 totalCommitments; 

    }

    // @notice check the poolId is not out of range
    modifier isValidPoolId(uint256 poolId) {
        require(poolId < _curPoolId, "LaunchPool Id is out of range.");
        _;
    }
    
    // @notice check the launchPool is not closed and not expired
    modifier isPoolOpen(uint256 poolId) {
        LaunchPool storage lp = poolsById[poolId];
        if (block.timestamp > lp.poolExpiry.startTime + lp.poolExpiry.duration) {
            lp.stage = PoolStatus.Closed;
        }
        require(!_atStage(poolId, PoolStatus.Closed), "LaunchPool is closed");
        _;
    }

    // called from the stakeVault. Adds to a list of the stakes in a pool, in stake order
    function addStake (uint256 poolId, uint256 stakeId) public isValidPoolId(poolId) {
        LaunchPool storage lp = poolsById[poolId];
        lp.stakes.push(stakeId);
    }

    // Get a list of stakes for the pool. This will be used by users, and also by the stakeVault
    // returns a list of IDs (figure out how to identify stakes in the stakevault. We know the pool)
    function getStakes (uint256 poolId) public returns(uint256[]) {
        Launchpool storage lp = poolsById[poolId];

        return lp.stakes;
    }
    
    // Put in committing status. Save a link to the offer
    // url contains the site that the description of the offer made by the sponsor
    function newOffer (uint256 poolId, string memory url, uint256 expiration) public isValidPoolId(poolId) isPoolOpen(poolId) {
        LaunchPool storage lp = poolsById[poolId];
        lp.stage = PoolStatus.AcceptingCommitments;
        lp.offerExpiry = expiration;
        lp.offer.url = url;
    }
    
    // put back in staking status.
    function cancelOffer (uint256 poolId) public {}
    
    // runs the logic for an offer that fails to reach minimum commitment, or succeeds and goes to Delivering status
    function endOffer (uint256 poolId) public {}
    
    // OPTIONAL IN THIS VERSION. calculates new dollar values for stakes. 
    // Eventually, we will save these values at the point were we go to “deliver” the investment amount based on the dollar value of a committed stake.
    function setValues () public {}
    
    // OPTIONAL IN THIS VERSION. We need a way to report the list of committed stakes, with the value of the committed stakes and the investor. 
    //This forms a list of the investments that need to be delivered. It is basically a “setValues” followed by getStakes.
    function getInvestmentValues () public {}
    
    // calls stakeVault closePool, sets status to closed
    function close (uint256 poolId) public {}

}