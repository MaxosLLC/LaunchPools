// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LaunchPoolTracker is Ownable {

       mapping(address => bool) private _allowedTokenAddresses;
    // Tokens to stake. We will upgrade this later.

    uint256 private _curPoolId; // count of pools in the array and map
    mapping(uint256 => LaunchPool) public poolsById;
    uint256[] public poolIds;

    enum LaunchPoolTrackerStatus {open, closed}
    LaunchPoolTrackerStatus status;
    StakeVault _stakeVault; //_stakeVault = StakeVault(stakeVaultAddress)
    
    struct LaunchPool {
        string name;
        address sponsor;
        PoolStatus stage;
        enum PoolStatus {AcceptingStakes, AcceptingCommitments, Funded, Closed}
        ExpiryData poolExpiry;
        ExpiryData offerExpiry;
        Offer offer;
        uint256[] stakes;

        // TODO: do we need these sums? Staked, committed? We can calculate dynamically
        // uint256 totalCommitments; 

    }

    // called from the stakeVault. Adds to a list of the stakes in a pool, in stake order
    function addStake (uint256 stakeId) public {}

    // Get a list of stakes for the pool. This will be used by users, and also by the stakeVault
    // returns a list of IDs (figure out how to identify stakes in the stakevault. We know the pool)
    function getStakes (uint256 poolId) public {}
    
    // Put in committing status. Save a link to the offer
    // url contains the site that the description of the offer made by the sponsor
    function newOffer (uint256 poolId, string url) public {}
    
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