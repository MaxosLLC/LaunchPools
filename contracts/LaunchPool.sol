// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/escrow/Escrow.sol";
import "./interfaces/IERC20Minimal.sol";
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

contract LaunchPool {
    enum Stages {AcceptingStakes, AcceptingCommitments, Funded, Closed}

    /** All pools start in this state  */
    Stages public stage = Stages.AcceptingStakes;

    uint256 public poolStartTime = block.timestamp;

    string public name;

    /** How long will this launchpool be valid for.  */
    uint256 public poolValidDuration;

    /** @dev the minimum amount an offer should gather in order to be redeemable */
    uint256 public minOfferAmount;

    /** @dev the maximum amount an offer can get. All stakes that are above this value
     * will not be used and will be returned to the account that staked them initially.
     * TODO: what do we do when stakedSoFar + currentStake > maxOfferAmount. We could clip
     * the stake and return the remainder.
     */
    uint256 public maxOfferAmount;

    /** When did the offer start? i.e., when were people allowed to commit? */
    uint256 public offerStartTime;

    /** Time the offer is valid for in ms */
    uint256 public offerValidDuration;

    /** If this value is empty, we assume people cannot commit  */
    string public offerUrl;

    uint256 private _placeInLine;

    /** Stakes indexed by id */
    mapping(uint256 => Stake) private _stakes;

    /** Allowed tokens  */
    mapping(address => bool) private _allowedTokenAddresses;

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
        uint256 maxOfferAmount_
    ) {
        require(
            allowedAddresses_.length >= 1 && allowedAddresses_.length <= 3,
            "There must be at least 1 and at most 3 tokens"
        );
        name = _poolName;
        poolValidDuration = poolValidDuration_;
        offerValidDuration = offerValidDuration_;
        minOfferAmount = minOfferAmount_;
        maxOfferAmount = maxOfferAmount_;

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
        require(
            (poolStartTime + poolValidDuration <= block.timestamp) &&
                (!_atStage(Stages.Closed)),
            "LaunchPool is closed"
        );
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
            (offerStartTime + offerValidDuration <= block.timestamp) &&
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
        isTokenAllowed(token)
        isPoolOpen
        canStake
    {
        address payee = msg.sender;
        uint256 stakeId = ++_placeInLine;

        // This adds a new stake to _stakes
        Stake storage s = _stakes[stakeId];

        s.id = stakeId;
        s.staker = payee;
        s.token = token;
        s.amount = amount;

        // TODO: call the vault contract
        // to transfer funds from user.

        emit Staked(payee, token, amount, stakeId);
    }

    function unstake(uint256 stakeId)
        external
        senderOwnsStake(stakeId)
        isPoolOpen
        canStake
    {
        require(!_stakesCommitted[stakeId], "cannot unstake commited stake");

        Stake memory s = _stakes[stakeId];
        delete _stakes[stakeId];

        // TODO: call vault to unstake
        emit Unstaked(msg.sender, s.token, s.amount, stakeId);
    }

    function setOffer(string memory offerUrl_) external isPoolOpen {
        // TODO this should only be callable by a sponsor
        offerStartTime = block.timestamp;
        offerUrl = offerUrl_;
        stage = Stages.AcceptingCommitments;
    }

    function commit(uint256 stakeId)
        external
        isPoolOpen
        isOfferOpen
        canCommit
        senderOwnsStake(stakeId)
    {
        _stakesCommitted[stakeId] = true;

        emit Committed(msg.sender, stakeId);
    }
}
