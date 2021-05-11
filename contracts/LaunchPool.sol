// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./StakeVault.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

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

/// @title A launch pool
contract LaunchPool is Ownable {
    enum Stages {AcceptingStakes, AcceptingCommitments, Funded, Closed}

    string public name;

    // All pools start in this state
    Stages public stage = Stages.AcceptingStakes;

    ExpiryData public poolExpiry;
    ExpiryData public offerExpiry;

    // When `offer.url` is empty, the pool is not ready for commitments
    Offer public offer;

    uint256 public stakeCount;
    uint256 public totalCommitments;

    uint256 private _placeInLine;
    StakeVault private _stakeVault;

    mapping(address => bool) private _allowedTokenAddresses;

    // stakes indexed by id
    mapping(uint256 => Stake) private _stakes;
    mapping(address => uint256[]) private _stakesByAccount;
    mapping(uint256 => bool) private _stakesCommitted;

    event Staked(
        address indexed payee,
        address indexed token,
        uint256 amount,
        uint256 stakeId
    );

    event Unstaked(
        address indexed payee,
        address indexed token,
        uint256 amount,
        uint256 stakeId
    );

    event Committed(address indexed payee, uint256 indexed stakeId);

    event UsedToFund(uint256 indexed stakeId, uint256 amount);

    /// @notice creates a new launchpool.
    /// @dev only 3 tokens are allowed to be staked.
    constructor(
        address[] memory allowedAddresses_,
        string memory _poolName,
        uint256 poolValidDuration_,
        uint256 offerValidDuration_,
        uint256 minOfferAmount_,
        uint256 maxOfferAmount_,
        address stakeVaultAddress
    ) {
        require(
            allowedAddresses_.length >= 1 && allowedAddresses_.length <= 3,
            "There must be at least 1 and at most 3 tokens"
        );
        name = _poolName;
        poolExpiry.startTime = block.timestamp;
        poolExpiry.duration = poolValidDuration_;

        offerExpiry.duration = offerValidDuration_;

        offer.bounds.minimum = minOfferAmount_;
        offer.bounds.maximum = maxOfferAmount_;

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

    function _atStage(Stages stage_) private view returns (bool) {
        return stage_ == stage;
    }

    modifier isTokenAllowed(address _tokenAddr) {
        require(
            _allowedTokenAddresses[_tokenAddr],
            "Cannot deposit that token"
        );
        _;
    }

    modifier isPoolOpen() {
        if (block.timestamp > poolExpiry.startTime + poolExpiry.duration) {
            stage = Stages.Closed;
        }

        require(!_atStage(Stages.Closed), "LaunchPool is closed");
        _;
    }

    modifier canStake() {
        require(
            _atStage(Stages.AcceptingStakes) ||
                _atStage(Stages.AcceptingCommitments),
            "Not in desired stage"
        );
        _;
    }

    modifier canCommit() {
        require(
            _atStage(Stages.AcceptingCommitments),
            "Not in either of desired stages"
        );
        _;
    }

    modifier senderOwnsStake(uint256 stakeId) {
        require(
            _stakes[stakeId].staker == msg.sender,
            "Account not authorized to unstake"
        );
        _;
    }

    modifier isOfferOpen() {
        require(
            (block.timestamp <= offerExpiry.startTime + offerExpiry.duration) &&
                _atStage(Stages.AcceptingCommitments),
            "Offer is closed"
        );
        _;
    }

    /// @notice Stake an ERC20 token
    /// @dev Token being staked should be `ERC20.approve`d to `StakeVault` contract,
    ///     otherwise this function reverts.
    function stake(address token, uint256 amount)
        external
        isPoolOpen
        isTokenAllowed(token)
        canStake
        returns (uint256)
    {
        address payee = msg.sender;
        // `_placeInLine` has to start in 1 because 0 represent not found.
        uint256 stakeId = ++_placeInLine;
        stakeCount++;

        // This adds a new stake to _stakes
        Stake storage s = _stakes[stakeId];

        s.id = stakeId;
        s.staker = payee;
        s.token = token;
        s.amount = amount;

        _stakesByAccount[payee].push(stakeId);

        _stakeVault.depositStake(token, amount, payee);

        emit Staked(payee, token, amount, stakeId);
        return stakeId;
    }

    /// @notice Remove a stake and returns funds to user.
    /// @dev This should be called by the staking user, otherwise it will revert.
    function unstake(uint256 stakeId)
        external
        isPoolOpen
        // If `stakeId` has already been unstaked
        // then _stakes[stakeId].staker == address(0)
        // and msg.sender != address(0)
        senderOwnsStake(stakeId)
        canStake
    {
        require(!_stakesCommitted[stakeId], "cannot unstake commited stake");

        address staker = msg.sender;
        Stake memory s = _stakes[stakeId];
        delete _stakes[stakeId];
        int256 stakeIdx = _findStake(staker, stakeId);
        assert(stakeIdx != -1);
        stakeCount--;

        _removeStakeFromAccount(staker, uint256(stakeIdx));

        _stakeVault.withdrawStake(s.token, s.amount, s.staker);
        emit Unstaked(staker, s.token, s.amount, stakeId);
    }

    function _findStake(address account, uint256 stakeId)
        private
        view
        returns (int256)
    {
        uint256 length = _stakesByAccount[account].length;
        for (uint256 i = 0; i < length; i++) {
            if (_stakesByAccount[account][i] == stakeId) {
                return int256(i);
            }
        }

        return -1;
    }

    function _removeStakeFromAccount(address account, uint256 stakeIdx)
        private
    {
        uint256[] memory accountStakes = _stakesByAccount[account];
        uint256 lastIdx = accountStakes.length - 1;
        if (stakeIdx != lastIdx) {
            // Move the last one to the stop we'd like to delete
            _stakesByAccount[account][stakeIdx] = _stakesByAccount[account][
                lastIdx
            ];
        }
        _stakesByAccount[account].pop();
    }

    /// @notice Sets the offer
    /// @dev Setting an offer causes the launchpool to be open for commits.
    function setOffer(string memory offerUrl_) external isPoolOpen onlyOwner {
        offerExpiry.startTime = block.timestamp;
        offer.url = offerUrl_;
        stage = Stages.AcceptingCommitments;
    }

    /// @notice Commit a previously added stake.
    function commit(uint256 stakeId)
        external
        isPoolOpen
        isOfferOpen
        canCommit
        senderOwnsStake(stakeId)
    {
        require(!_stakesCommitted[stakeId], "Stake is already committed");
        require(_stakes[stakeId].staker != address(0), "Stake doesn't exist");

        _stakesCommitted[stakeId] = true;
        totalCommitments += _stakes[stakeId].amount;

        emit Committed(msg.sender, stakeId);
    }

    function stakesOf(address account) public view returns (uint256[] memory) {
        return _stakesByAccount[account];
    }

    function _isAfterOfferClose() private view returns (bool) {
        return block.timestamp >= offerExpiry.startTime + offerExpiry.duration;
    }

    function canRedeemOffer() public view returns (bool) {
        return _isAfterOfferClose() && totalCommitments >= offer.bounds.minimum;
    }

    /// @notice Redeem an offer.
    /// @dev Try to use all committments to fulfill and redeem an offer.
    ///     This involves sending all collected funds to an address
    ///     specified on the vault.
    function redeemOffer() public onlyOwner {
        require(canRedeemOffer(), "Not enough funds committed");
        require(_isAfterOfferClose(), "The offer is still open");

        for (uint256 stakeId = 1; stakeId <= stakeCount; stakeId++) {
            console.log("here", stakeId);
            if (_stakes[stakeId].staker == address(0)) {
                continue;
            }

            if (!_stakesCommitted[stakeId]) {
                continue;
            }

            console.log("here1", stakeId);

            // TODO: look into re-entrancy problems.
            _stakeVault.encumber(
                _stakes[stakeId].staker,
                _stakes[stakeId].token,
                _stakes[stakeId].amount
            );

            console.log("here2", stakeId);

            _stakesCommitted[stakeId] = false;
            emit UsedToFund(stakeId, _stakes[stakeId].amount);
        }

        stage = Stages.Funded;
        totalCommitments = 0;

        _stakeVault.withdraw();
    }
}
