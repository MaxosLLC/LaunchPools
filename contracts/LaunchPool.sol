// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./StakeVault.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

struct Stake {
    /** Starts with 1. Determines the position in line as well as the id. */
    uint256 id;
    /** Account who added this stake. */
    address staker;
    /** Token being staked. For now only ERC20 */
    address token;
    /** Amount staked */
    uint256 amount;
}

/** @dev This helps us track how long a certain thing is valid or available for.*/
struct ExpiryData {
    uint256 startTime;
    uint256 duration;
}

/** @dev The min and max values for an offer.
 * If we have less than `minimum`, the offer cannot be redeemed.
 * If we have more than `maximum`, some stakes will not be considered.
 */
struct OfferBounds {
    uint256 minimum;
    /** @dev the maximum amount an offer can get. All stakes that are above this value
     * will not be used and will be returned to the account that staked them initially.
     * TODO: what do we do when stakedSoFar + currentStake > maxOfferAmount. We could clip
     * the stake and return the remainder.
     */
    uint256 maximum;
}

/** @dev data of an offer */
struct Offer {
    OfferBounds bounds;
    string url;
}

contract LaunchPool is Ownable {
    enum Stages {AcceptingStakes, AcceptingCommitments, Funded, Closed}

    string public name;

    /** All pools start in this state  */
    Stages public stage = Stages.AcceptingStakes;

    ExpiryData public poolExpiry;
    ExpiryData public offerExpiry;

    /** When `offer.url` is empty, the pool is not ready for commitments */
    Offer public offer;

    uint256 public stakeCount;
    uint256 public totalCommitments;

    uint256 private _placeInLine;
    StakeVault private _stakeVault;

    /** Allowed tokens  */
    mapping(address => bool) private _allowedTokenAddresses;

    /** Stakes indexed by id */
    mapping(uint256 => Stake) private _stakes;

    /** Stakes for each account */
    mapping(address => uint256[]) private _stakesByAccount;

    /** Commited stakes */
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

    /** @dev This allows you to stake some ERC20 token. Make sure
     * You `ERC20.approve` to `LaunchPool` contract before you stake.
     */
    function stake(address token, uint256 amount)
        external
        isPoolOpen
        isTokenAllowed(token)
        canStake
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
    }

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

    function setOffer(string memory offerUrl_) external isPoolOpen onlyOwner {
        offerExpiry.startTime = block.timestamp;
        offer.url = offerUrl_;
        stage = Stages.AcceptingCommitments;
    }

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

    function canRedeemOffer() public view returns (bool) {
        return totalCommitments >= offer.bounds.minimum;
    }
}
