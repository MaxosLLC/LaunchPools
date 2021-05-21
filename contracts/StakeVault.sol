// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./interfaces/IERC20Minimal.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

/// @notice A vault to manage tokens
/// @dev Vault contract used to manage token's transfers for a launchpool.
///     When a vault is created, a `withdrawAddress` is set. This address will
///     receive the funds once they are withdrawn.
contract StakeVault is Ownable {

    struct PoolDeposit {
        uint256 _totalDeposited;

        // payee -> token -> deposit
        mapping(address => mapping(address => uint256)) _deposits;

        // payee -> totalDeposits
        mapping(address => uint256) _depositsByAccount;

        // payee -> canWithdraw
        mapping(address => bool) _shouldWithdrawToken;

        // payee -> amount
        mapping(address => uint256) _amountToWithdraw;

        address[] _tokensToWithdraw;
    }

    address private _poolTrackerContract;

    uint256 public totalDeposited;

    /** @dev Holds will be withdrawn to this address. Cannot be changed once the contract is deployed */
    address public withdrawAddress;

    // poolId -> all pool deposits
    mapping(uint256 => PoolDeposit) private _poolDeposits;

    constructor(address withdrawAddress_) {
        withdrawAddress = withdrawAddress_;
    }

    modifier calledByPool() {
        require(_poolTrackerContract != address(0), "pool contract not set");
        require(_poolTrackerContract == msg.sender, "sender is not the pool contract");
        _;
    }

    /// @dev Of the pool contract is not set, none of the methods in this contract work.
    function setPoolContract(address poolContract) public onlyOwner {
        _poolTrackerContract = poolContract;
    }

    /// @notice Transfer ERC20 funds from the user to the vault.
    function depositStake(
        uint256 poolId,
        address token,
        uint256 amount,
        address payee
    ) public calledByPool {
        PoolDeposit storage pd = _poolDeposits[poolId];

        pd._depositsByAccount[payee] = pd._depositsByAccount[payee] + amount;
        pd._deposits[payee][token] = pd._deposits[payee][token] + amount;
        pd._totalDeposited += amount;
        totalDeposited += amount;

        // If the transfer fails, we revert and don't record the amount.
        require(
            IERC20Minimal(token).transferFrom(payee, address(this), amount),
            "Did not get the moneys"
        );

        // Assert here so we have peace of mind
        assert(pd._depositsByAccount[payee] <= pd._totalDeposited);
    }

    /// @notice Withdraw a stake.
    function withdrawStake(
        uint256 poolId,
        address token,
        uint256 amount,
        address payee
    ) public calledByPool {
        require(
            depositsOfByToken(poolId, payee, token) >= amount,
            "Player has less than requested amount"
        );

        _removeAmount(poolId, payee, token, amount);

        require(
            IERC20Minimal(token).transfer(payee, amount),
            "Could not send the moneys"
        );

        assert(_poolDeposits[poolId]._depositsByAccount[payee] <= totalDeposited);
    }

    function depositsOf(uint256 poolId, address payee) public view returns (uint256) {
        return _poolDeposits[poolId]._depositsByAccount[payee];
    }

    function depositsOfByToken(uint256 poolId, address payee, address token)
        public
        view
        returns (uint256)
    {
        return _poolDeposits[poolId]._deposits[payee][token];
    }

    function _removeAmount(
        uint256 poolId,
        address payee,
        address token,
        uint256 amount
    ) private {
        totalDeposited -= amount;

        PoolDeposit storage pd = _poolDeposits[poolId];
        pd._totalDeposited -= amount;
        pd._depositsByAccount[payee] -= amount;
        pd._deposits[payee][token] -= amount;
    }

    /// @dev encumbers a token from a payee to be later withdrawn by an account.
    ///     In order words, it marks a certain amount for certain token to
    ///     be sent to the `withdrawAddress`
    function encumber(
        uint256 poolId,
        address payee,
        address token,
        uint256 amount
    ) public calledByPool {
        require(
            depositsOfByToken(poolId, payee, token) >= amount,
            "Not enough tokens to encumber"
        );

        _removeAmount(poolId, payee, token, amount);

        PoolDeposit storage pd = _poolDeposits[poolId];

        if (!pd._shouldWithdrawToken[token]) {
            pd._shouldWithdrawToken[token] = true;
            pd._tokensToWithdraw.push(token);
        }

        pd._amountToWithdraw[token] += amount;
    }

    /// @dev Withdraw the funds for a pool to the specified address.
    function withdraw(uint256 poolId) public calledByPool {
        PoolDeposit storage pd = _poolDeposits[poolId];

        for (int256 i = 0; i < int256(pd._tokensToWithdraw.length); i++) {
            address token = pd._tokensToWithdraw[uint256(i)];

            require(
                IERC20Minimal(token).transfer(
                    withdrawAddress,
                    pd._amountToWithdraw[token]
                ),
                "Could not send the moneys"
            );
        }
    }
}
