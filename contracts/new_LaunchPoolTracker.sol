// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./new_StakeVault.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract LaunchPoolTracker is Ownable {

    mapping(address => bool) public _allowedTokenAddresses;
    // Tokens to stake. We will upgrade this later.
    

    /// @dev This helps us track how long a certain thing is valid or available for.
    struct ExpiryData {
        uint256 startTime;
        uint256 duration;
    }

    /// @notice The min and max values for an offer.
    /// @dev The min and max values for an offer.
    ///          if we have less than `minimum`, the offer cannot be redeemed.
    ///          if we have more than `maximum`, some stakes will not be considered.
    ///
    struct OfferBounds {
        uint256 minimum;
        /// @dev the maximum amount an offer can get. All stakes that are above this value
        ///     will not be used and will be returned to the account that staked them initially.
        ///     TODO: what do we do when stakedSoFar + currentStake > maxOfferAmount. We could clip
        ///     the stake and return the remainder.
        ///
        uint256 maximum;
    }

    /// @dev data of an offer
    struct Offer {
        OfferBounds bounds;
        string url;
    }

    uint256 private _curPoolId; // count of pools in the array and map
    mapping(uint256 => LaunchPool) public poolsById;
    uint256[] public poolIds;

    enum LaunchPoolTrackerStatus {open, closed}
    enum PoolStatus {AcceptingStakes, AcceptingCommitments, Funded, Closed}

    LaunchPoolTrackerStatus status;
    StakeVault _stakeVault; //_stakeVault = StakeVault(stakeVaultAddress)
    
    struct LaunchPool {
        string name;
        address sponsor;
        PoolStatus stage;
        ExpiryData poolExpiry;
        ExpiryData offerExpiry;
        Offer offer;
        uint256[] stakes;

        // TODO: do we need these sums? Staked, committed? We can calculate dynamically
        // uint256 totalCommitments; 

    }

    function addStake (uint256 stakeId) public {}

    function getStakes (uint256 poolId) public {}
    
    function newOffer (uint256 poolId, string memory url) public {}
    
    function cancelOffer (uint256 poolId) public {}
    
    function endOffer (uint256 poolId) public {}
    
    function setValues () public {}
    
    function getInvestmentValues () public {}
    
    function close (uint256 poolId) public {}

}