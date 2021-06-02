// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;



import "./StakeVault.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";



contract LaunchPoolTrackerNew is Ownable {



    mapping(address => bool) private _allowedTokenAddresses;

    // Tokens to stake. We will upgrade this later.



    uint256 private _curPoolId; // count of pools in the array and map

    mapping(uint256 => LaunchPool) public poolsById;

    uint256[] public poolIds;



    enum LaunchPoolTrackerStatus {open, closed}

    LaunchPoolTrackerStatus status;

    StakeVault _stakeVault; //_stakeVault = StakeVault(stakeVaultAddress)

    



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

        uint256 totalCommitAmount; 



    }



    /// @notice creates a new LaunchPoolTracker.

    /// @dev up to 3 tokens are allowed to be staked.

    constructor(address[] memory allowedAddresses_, address stakeVaultAddress) {

        require(

            allowedAddresses_.length >= 1 && allowedAddresses_.length <= 3,

            "There must be at least 1 and at most 3 tokens"

        );



        // TOOD on my testing a for loop didn't work here, hence this uglyness.

        _allowedTokenAddresses[allowedAddresses_[0]] = true;

        if (allowedAddresses_.length >= 2) {

            _allowedTokenAddresses[allowedAddresses_[1]] = true;

        }



        if (allowedAddresses_.length == 3) {

            _allowedTokenAddresses[allowedAddresses_[2]] = true;

        }



        _stakeVault = StakeVault(stakeVaultAddress);

        status = LaunchPoolTrackerStatus.open;

        _stakevault._poolTrackerContract = address(this)

    }



    // @notice add launchPool info and call addPool in stakeVault contract

    function addPool(

        string memory _poolName,

        uint256 poolValidDuration_,

        uint256 offerValidDuration_,

        uint256 minOfferAmount_,

        uint256 maxOfferAmount_) public {



        uint256 currPoolId = ++_curPoolId;

        LaunchPool storage lp = poolsById[currPoolId];



        lp.name = _poolName;

        lp.stage = PoolStatus.AcceptingStakes;

        lp.poolExpiry.startTime = block.timestamp;

        lp.poolExpiry.duration = poolValidDuration_;



        lp.offerExpiry.duration = offerValidDuration_;



        lp.offer.bounds.minimum = minOfferAmount_;

        lp.offer.bounds.maximum = maxOfferAmount_;



        poolIds.push(currPoolId);



        _stakeVault.addPool(currPoolId, msg.sender, block.timestamp+poolValidDuration_);

    }



    // @notice get all launchPool info list

    function getPoolIds() public returns (uint256[]) {

        return poolIds;

    }



    // @notice check the launchPool stage is the same as stage_

    function _atStage(uint256 poolId, Stages stage_) private view returns (bool) {

        LaunchPool storage lp = poolsById[poolId];

        return lp.stage == stage_;

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

            lp.stage = lp.PoolStatus.Closed;

        }



        require(!_atStage(poolId, lp.PoolStatus.Closed), "LaunchPool is closed");

        _;

    }



    // @notice Add a stakeID into stake list in launchPool

    function addStake (uint256 poolId, uint256 stakeId) public isValidPoolId(poolId) {

        LaunchPool storage lp = poolsById(poolId);



        lp.stakes.push(stakeId);

    }



    // @notice Get stake ID List in launchPool

    function getStakes (uint256 poolId) public returns(uint256[]) {

        LaunchPool storage lp = poolsById(poolId);



        return lp.stakes;

    }

    

    // @notice Set offer url and stage into AcceptingCommitments in launchPool 

    function newOffer (uint256 poolId, string memory url) public isValidPoolId(poolId) isPoolOpen(poolId) {

        LaunchPool storage lp = poolsById(poolId);



        lp.stage = lp.PoolStatus.AcceptingCommitments;

        lp.offerExpiry.startTime = block.timestamp;

        lp.offer.url = url;

    }

    

    // @notice Set stage back to AcceptingStakes in launchPool

    function cancelOffer (uint256 poolId) public isValidPoolId(poolId) {

        LaunchPool storage lp = poolsById(poolId);



        lp.stage = lp.PoolStatus.AcceptingStakes;

    }

    

    // @notice Check the launchPool offer is expired or not

    function _isAfterOfferClose(uint256 poolId) private view returns (bool) {

        LaunchPool storage lp = poolsById[poolId];

        return block.timestamp >= lp.offerExpiry.startTime + lp.offerExpiry.duration;

    }



    // @notice Check the launchPool offer is able to claim or not

    function canClaimOffer(uint256 poolId) public view returns (bool) {

        LaunchPool storage lp = poolsById[poolId];

        return _isAfterOfferClose(poolId) && lp.totalCommitAmount >= lp.offer.bounds.minimum;

    }

    

    // @notice Check the offer success or failure and runs proper action

    function endOffer (uint256 poolId) public {

        LaunchPool storage lp = poolsById[poolId];



        if(canClaimOffer(poolId)) {

            lp.stage = lp.PoolStatus.Funded;

        }



        if(!canClaimOffer(poolId)) {

            lp.stage = lp.PoolStatus.AcceptingStakes;

            _stakeVault.unCommitStakes(poolId);

        }

    }

    

    function setValues () public {}

    

    function getInvestmentValues () public {}

    

    // @notice end LauchPool and set stage into Closed

    function closePool (uint256 poolId) public isValidPoolId(poolId) {

        _stakeVault.closePool(poolId);

        LaunchPool storage lp = poolsById(poolId);



        lp.stage = lp.PoolStatus.Closed;

    }



}

