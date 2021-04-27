// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import "@openzeppelin/contracts/utils/escrow/Escrow.sol";
import "./interfaces/IERC20Minimal.sol";
import "hardhat/console.sol";

contract LaunchPool {
    string public name;
    uint256 public maxCommitment;
    uint256 public minCommitment;

    uint256 private _endTimestamp;
    uint256 private _totalStaked;
    uint256 private _accountsStakeCount;

    mapping(address => mapping(address => uint256)) private _stakes;
    mapping(address => bool) private _allowedTokenAddresses;
    mapping(address => uint256) private _stakesByAccount;

    event Staked(address indexed payee, address indexed token, uint256 amount);
    event Unstaked(
        address indexed payee,
        address indexed token,
        uint256 amount
    );

    constructor(
        address[] memory allowedAddresses_,
        string memory _poolName,
        uint256 _minCommitment,
        uint256 _maxCommitment,
        uint256 endTimestamp_
    ) {
        // Allow at most 3 coins
        require(
            allowedAddresses_.length >= 1 && allowedAddresses_.length <= 3,
            "There must be at least 1 and at most 3 tokens"
        );
        name = _poolName;
        minCommitment = _minCommitment;
        maxCommitment = _maxCommitment;
        _endTimestamp = endTimestamp_;

        _allowedTokenAddresses[allowedAddresses_[0]] = true;
        if (allowedAddresses_.length >= 2) {
            _allowedTokenAddresses[allowedAddresses_[1]] = true;
        }

        if (allowedAddresses_.length == 3) {
            _allowedTokenAddresses[allowedAddresses_[2]] = true;
        }
    }

    modifier isTokenAllowed(address _tokenAddr) {
        require(
            _allowedTokenAddresses[_tokenAddr],
            "Cannot deposit that token"
        );
        _;
    }

    modifier isLaunchPoolOpen() {
        require(block.timestamp <= _endTimestamp, "LaunchPool is closed");
        _;
    }

    modifier hasRoomForDeposit(uint256 amount) {
        require(
            _totalStaked + amount <= maxCommitment,
            "Maximum staked amount exceeded"
        );
        _;
    }

    /** @dev This allows you to stake some ERC20 token. Make sure
     * You `ERC20.approve` to `LaunchPool` contract before you stake.
     */
    function stake(address token, uint256 amount)
        external
        isTokenAllowed(token)
        isLaunchPoolOpen
        hasRoomForDeposit(amount)
    {
        address payee = msg.sender;

        if (!_accountHasStaked(payee)) {
            _accountsStakeCount += 1;
        }

        _stakesByAccount[payee] = _stakesByAccount[payee] + amount;
        _stakes[payee][token] = _stakes[payee][token] + amount;
        _totalStaked += amount;

        // If the transfer fails, we revert and don't record the amount.
        require(
            IERC20Minimal(token).transferFrom(
                msg.sender,
                address(this),
                amount
            ),
            "Did not get the moneys"
        );

        emit Staked(payee, token, amount);
    }

    function unstake(address token) external isTokenAllowed(token) {
        uint256 currStake = _stakes[msg.sender][token];

        _totalStaked -= currStake;
        _stakesByAccount[msg.sender] -= currStake;
        _stakes[msg.sender][token] = 0;

        if (!_accountHasStaked(msg.sender)) {
            _accountsStakeCount -= 1;
        }

        require(
            IERC20Minimal(token).transfer(msg.sender, currStake),
            "Could not send the moneys"
        );

        emit Unstaked(msg.sender, token, currStake);
    }

    function stakesOf(address payee, address token)
        public
        view
        returns (uint256)
    {
        return _stakes[payee][token];
    }

    function totalStakesOf(address payee) public view returns (uint256) {
        return _stakesByAccount[payee];
    }

    function totalStakes() public view returns (uint256) {
        return _totalStaked;
    }

    function isFunded() public view returns (bool) {
        return _totalStaked >= minCommitment;
    }

    function endTimestamp() public view returns (uint256) {
        return _endTimestamp;
    }

    /** Kind of a weird name. Will change it eventually. */
    function stakeCount() public view returns (uint256) {
        return _accountsStakeCount;
    }

    function _accountHasStaked(address account) private view returns (bool) {
        return _stakesByAccount[account] != 0;
    }
}
