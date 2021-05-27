// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./StakeVault.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";


/// @title A launch pool
contract LaunchPoolTracker is Ownable {
    /// @title A stake
    struct Stake {
        /// @notice Identifier for a stake.
        /// @dev This id is given every time a new stake is created. It's always increasing.
        uint256 id;
        /// @notice The account that added this stake
        address staker;
        /// @notice Address of token being staked.
        address token;
        /// @notice Amount being staked
        /// @dev We are assuming all tokens have the same amount of digits.
        uint256 amount;
    }

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

    enum Stages {AcceptingStakes, AcceptingCommitments, Funded, Closed}

    struct LaunchPool {
        /// @dev name of a launchpool
        string name;

        /// @dev current stage
        Stages stage;

        /// @dev expiration times for pool and offer
        ExpiryData poolExpiry;
        ExpiryData offerExpiry;

        /// @dev current offer for this pool
        Offer offer;

        /// @dev total amount of stakes
        /// uint256 stakeCount;

        /// @dev total amount committed
        /// uint256 totalCommitments;
        
        /// dmitriy : change stakeAmount variable name
        uint256 totalStakeAmount;

        /// dmitriy : add stakeCount variable
        uint256 stakeCount;

        /// dmitriy : change commitAmount variable name
        uint256 totalCommitAmount;

        /// dmitriy : add commitCount variable
        uint256 commitCount;

        /// @dev place in line
        uint256 _placeInLine;

        // @dev stakeId -> Stake
        mapping(uint256 => Stake) _stakes;

        /// @dev account => stakeIdList
        mapping(address => uint256[]) _stakesByAccount;

        /// @dev stakeId => bool
        mapping(uint256 => bool) _stakesCommitted;
    }

    mapping(address => bool) private _allowedTokenAddresses;
    uint256 private _curPoolId;
    mapping(uint256 => LaunchPool) public poolsById;
    uint256[] public poolIds;

    StakeVault _stakeVault;

    event Staked(
        uint256 indexed poolId,
        address indexed payee,
        address indexed token,
        uint256 amount,
        uint256 stakeId
    );

    event Unstaked(
        uint256 indexed poolId,
        address indexed payee,
        address indexed token,
        uint256 amount,
        uint256 stakeId
    );

    event Committed(uint256 indexed poolId, address indexed payee, uint256 indexed stakeId);

    event UsedToFund(uint256 indexed poolId, uint256 indexed stakeId, uint256 amount);

    /// @notice creates a new LaunchPoolTracker.
    /// @dev up to 3 tokens are allowed to be staked.
    constructor(address[] memory allowedAddresses_, address stakeVaultAddress) {
        require(
            allowedAddresses_.length >= 1 && allowedAddresses_.length <= 3,
            "There must be at least 1 and at most 3 tokens"
        );

        _stakeVault = StakeVault(stakeVaultAddress);
        // TOOD on my testing a for loop didn't work here, hence this uglyness.
        _allowedTokenAddresses[allowedAddresses_[0]] = true;
        if (allowedAddresses_.length >= 2) {
            _allowedTokenAddresses[allowedAddresses_[1]] = true;
        }

        if (allowedAddresses_.length == 3) {
            _allowedTokenAddresses[allowedAddresses_[2]] = true;
        }
    }

    function addLaunchPool(
        string memory _poolName,
        uint256 poolValidDuration_,
        uint256 offerValidDuration_,
        uint256 minOfferAmount_,
        uint256 maxOfferAmount_) public {

        uint256 currPoolId = ++_curPoolId;
        LaunchPool storage lp = poolsById[currPoolId];

        lp.name = _poolName;
        lp.stage = Stages.AcceptingStakes;
        lp.poolExpiry.startTime = block.timestamp;
        lp.poolExpiry.duration = poolValidDuration_;

        lp.offerExpiry.duration = offerValidDuration_;

        lp.offer.bounds.minimum = minOfferAmount_;
        lp.offer.bounds.maximum = maxOfferAmount_;

        poolIds.push(currPoolId);
    }

    function _atStage(uint256 poolId, Stages stage_) private view returns (bool) {
        LaunchPool storage lp = poolsById[poolId];
        return lp.stage == stage_;
    }

    modifier isTokenAllowed(address _tokenAddr) {
        require(
            _allowedTokenAddresses[_tokenAddr],
            "Cannot deposit that token"
        );
        _;
    }

    modifier isPoolOpen(uint256 poolId) {
        LaunchPool storage lp = poolsById[poolId];

        if (block.timestamp > lp.poolExpiry.startTime + lp.poolExpiry.duration) {
            lp.stage = Stages.Closed;
        }

        require(!_atStage(poolId, Stages.Closed), "LaunchPool is closed");
        _;
    }

    modifier canStake(uint256 poolId) {
        require(
            _atStage(poolId, Stages.AcceptingStakes) ||
                _atStage(poolId, Stages.AcceptingCommitments),
            "Not in desired stage"
        );
        _;
    }

    modifier canCommit(uint256 poolId) {
        require(
            _atStage(poolId, Stages.AcceptingCommitments),
            "Not in either of desired stages"
        );
        _;
    }

    modifier senderOwnsStake(uint256 poolId, uint256 stakeId) {
        LaunchPool storage lp = poolsById[poolId];
        require(
            lp._stakes[stakeId].staker == msg.sender,
            "Account not authorized to unstake"
        );
        _;
    }

    modifier isOfferOpen(uint256 poolId) {
        LaunchPool storage lp = poolsById[poolId];

        require(
            (block.timestamp <= lp.offerExpiry.startTime + lp.offerExpiry.duration) &&
                _atStage(poolId, Stages.AcceptingCommitments),
            "Offer is closed"
        );
        _;
    }

    /// @notice Stake an ERC20 token
    /// @dev Token being staked should be `ERC20.approve`d to `StakeVault` contract,
    ///     otherwise this function reverts.
    function stake(uint256 poolId, address token, uint256 amount)
        external
        isPoolOpen(poolId)
        isTokenAllowed(token)
        canStake(poolId)
        returns (uint256) {
        LaunchPool storage lp = poolsById[poolId];
        address payee = msg.sender;
        // `_placeInLine` has to start in 1 because 0 represent not found.
        uint256 stakeId = ++lp._placeInLine;
        lp.stakeCount++;

        // This adds a new stake to _stakes
        Stake storage s = lp._stakes[stakeId];

        s.id = stakeId;
        s.staker = payee;
        s.token = token;
        s.amount = amount;

        lp._stakesByAccount[payee].push(stakeId);

        /// dmitriy : add totalStakeAmount calculation private
        lp.totalStakeAmount +=  amount;

        _stakeVault.depositStake(poolId, token, amount, payee);

        emit Staked(poolId, payee, token, amount, stakeId);
        return stakeId;
    }

    /// @notice Remove a stake and returns funds to user.
    /// @dev This should be called by the staking user, otherwise it will revert.
    function unstake(uint256 poolId, uint256 stakeId) external
        isPoolOpen(poolId)
        // If `stakeId` has already been unstaked
        // then _stakes[stakeId].staker == address(0)
        // and msg.sender != address(0)
        senderOwnsStake(poolId, stakeId)
        canStake(poolId)
    {
        LaunchPool storage lp = poolsById[poolId];
        require(!lp._stakesCommitted[stakeId], "cannot unstake commited stake");

        address staker = msg.sender;
        Stake memory s = lp._stakes[stakeId];
        // TODO: Filipe suggested we dont use stakeId as an absolute number but as the
        //      index of the list. This way, we don't need to move things around like we
        //      are doing here.

        /// dmitriy : add totalStakeAmount calculation private
        lp.totalStakeAmount -= lp._stakes[stakeId].amount;

        delete lp._stakes[stakeId];
        int256 stakeIdx = _findStake(poolId, staker, stakeId);
        assert(stakeIdx != - 1);
        lp.stakeCount--;

        _removeStakeFromAccount(poolId, staker, uint256(stakeIdx));

        _stakeVault.withdrawStake(poolId, s.token, s.amount, s.staker);
        emit Unstaked(poolId, staker, s.token, s.amount, stakeId);
    }

    function _findStake(uint256 poolId, address account, uint256 stakeId)
        private
        view
        returns (int256)
    {
        LaunchPool storage lp = poolsById[poolId];

        uint256 length = lp._stakesByAccount[account].length;
        for (uint256 i = 0; i < length; i++) {
            if (lp._stakesByAccount[account][i] == stakeId) {
                return int256(i);
            }
        }

        return -1;
    }

    function _removeStakeFromAccount(uint256 poolId, address account, uint256 stakeIdx)
        private
    {
        LaunchPool storage lp = poolsById[poolId];

        uint256[] memory accountStakes = lp._stakesByAccount[account];
        uint256 lastIdx = accountStakes.length - 1;
        if (stakeIdx != lastIdx) {
            // Move the last one to the stop we'd like to delete
            lp._stakesByAccount[account][stakeIdx] = lp._stakesByAccount[account][
                lastIdx
            ];
        }
        lp._stakesByAccount[account].pop();
    }

    /// @notice Sets the offer
    /// @dev Setting an offer causes the launchpool to be open for commits.
    function setOffer(uint256 poolId, string memory offerUrl_) external isPoolOpen(poolId) onlyOwner {
        LaunchPool storage lp = poolsById[poolId];

        lp.offerExpiry.startTime = block.timestamp;
        lp.offer.url = offerUrl_;
        lp.stage = Stages.AcceptingCommitments;
    }

    /// @notice Commit a previously added stake.
    function commit(uint256 poolId, uint256 stakeId)
        external
        isPoolOpen(poolId)
        isOfferOpen(poolId)
        canCommit(poolId)
        senderOwnsStake(poolId, stakeId)
    {
        LaunchPool storage lp = poolsById[poolId];
        require(!lp._stakesCommitted[stakeId], "Stake is already committed");
        require(lp._stakes[stakeId].staker != address(0), "Stake doesn't exist");

        lp._stakesCommitted[stakeId] = true;

        /// dmitriy : change variable name
        lp.totalCommitAmount += lp._stakes[stakeId].amount;

        /// dmitriy : add commitCount calculation part
        lp.commitCount ++;

        emit Committed(poolId, msg.sender, stakeId);
    }

    /// dmitriy : add get poolIds function
    function getPoolIds() public view returns (uint256 [] memory) {
        return poolIds;
    }

    function stakesOf(uint256 poolId, address account) public view returns (uint256[] memory) {
        LaunchPool storage lp = poolsById[poolId];
        return lp._stakesByAccount[account];
    }

    function poolStakeCount(uint256 poolId) public view returns (uint256) {
        LaunchPool storage lp = poolsById[poolId];
        return lp.stakeCount;
    }

    /// dmitriy : add get totalStakeAmount function
    function poolTotalStakeAmount(uint256 poolId) public view returns (uint256) {
        LaunchPool storage lp = poolsById[poolId];
        return lp.totalStakeAmount;
    }

    /// dmitriy : add get commitCount function
    function poolCommitCount(uint256 poolId) public view returns (uint256) {
        LaunchPool storage lp = poolsById[poolId];
        return lp.commitCount;
    }

    /// dmitriy : change function name
    function poolTotalCommitAmount(uint256 poolId) public view returns (uint256) {
        LaunchPool storage lp = poolsById[poolId];

        /// dmitriy : change variable name
        return lp.totalCommitAmount;
    }

    function _isAfterOfferClose(uint256 poolId) private view returns (bool) {
        LaunchPool storage lp = poolsById[poolId];
        return block.timestamp >= lp.offerExpiry.startTime + lp.offerExpiry.duration;
    }

    function canRedeemOffer(uint256 poolId) public view returns (bool) {
        LaunchPool storage lp = poolsById[poolId];
        return _isAfterOfferClose(poolId) && lp.totalCommitAmount >= lp.offer.bounds.minimum;
    }

    /// @notice Redeem an offer.
    /// @dev Try to use all committments to fulfill and redeem an offer.
    ///     This involves sending all collected funds to an address
    ///     specified on the vault.
    function redeemOffer(uint256 poolId) public onlyOwner {
        require(canRedeemOffer(poolId), "Not enough funds committed");
        require(_isAfterOfferClose(poolId), "The offer is still open");

        LaunchPool storage lp = poolsById[poolId];
        for (uint256 stakeId = 1; stakeId <= lp.stakeCount; stakeId++) {
            if (lp._stakes[stakeId].staker == address(0)) {
                continue;
            }

            if (!lp._stakesCommitted[stakeId]) {
                continue;
            }

            // TODO: look into re-entrancy problems.
            _stakeVault.encumber(
                poolId,
                lp._stakes[stakeId].staker,
                lp._stakes[stakeId].token,
                lp._stakes[stakeId].amount
            );

            lp._stakesCommitted[stakeId] = false;
            emit UsedToFund(poolId, stakeId, lp._stakes[stakeId].amount);
        }

        lp.stage = Stages.Funded;

        /// dmitriy : change variable name
        lp.totalCommitAmount = 0;

        /// dmitriy : add commitCount calculation part
        lp.commitCount = 0;

        _stakeVault.withdraw(poolId);
    }
}
