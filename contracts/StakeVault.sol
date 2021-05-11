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
    address private _poolContract;

    uint256 public totalDeposited;

    /** @dev Holds will be withdrawn to this address. Cannot be changed once the contract is deployed */
    address public withdrawAddress;

    constructor(address withdrawAddress_) {
        withdrawAddress = withdrawAddress_;
    }

    mapping(address => mapping(address => uint256)) private _deposits;
    mapping(address => uint256) private _depositsByAccount;

    mapping(address => bool) private _shouldWithdrawToken;
    mapping(address => uint256) private _amountToWithdraw;
    address[] private _tokensToWithdraw;

    modifier calledByPool() {
        require(_poolContract != address(0), "pool contract not set");
        require(_poolContract == msg.sender, "sender is not the pool contract");
        _;
    }

    /// @dev Of the pool contract is not set, none of the methods in this contract work.
    function setPoolContract(address poolContract) public onlyOwner {
        _poolContract = poolContract;
    }

    /// @notice Transfer ERC20 funds from the user to the vault.
    function depositStake(
        address token,
        uint256 amount,
        address payee
    ) public calledByPool {
        _depositsByAccount[payee] = _depositsByAccount[payee] + amount;
        _deposits[payee][token] = _deposits[payee][token] + amount;
        totalDeposited += amount;

        // If the transfer fails, we revert and don't record the amount.
        require(
            IERC20Minimal(token).transferFrom(payee, address(this), amount),
            "Did not get the moneys"
        );

        // Assert here so we have peace of mind
        assert(_depositsByAccount[payee] <= totalDeposited);
    }

    /// @notice Withdraw a stake.
    function withdrawStake(
        address token,
        uint256 amount,
        address payee
    ) public calledByPool {
        require(
            depositsOfByToken(payee, token) >= amount,
            "Player has less than requested amount"
        );

        _removeAmount(payee, token, amount);

        require(
            IERC20Minimal(token).transfer(payee, amount),
            "Could not send the moneys"
        );

        assert(_depositsByAccount[payee] <= totalDeposited);
    }

    function depositsOf(address payee) public view returns (uint256) {
        return _depositsByAccount[payee];
    }

    function depositsOfByToken(address payee, address token)
        public
        view
        returns (uint256)
    {
        return _deposits[payee][token];
    }

    function _removeAmount(
        address payee,
        address token,
        uint256 amount
    ) private {
        totalDeposited -= amount;
        _depositsByAccount[payee] -= amount;
        _deposits[payee][token] -= amount;
    }

    /// @dev encumbers a token from a payee to be later withdrawn by an account.
    ///     In order words, it marks a certain amount for certain token to
    ///     be sent to the `withdrawAddress`
    function encumber(
        address payee,
        address token,
        uint256 amount
    ) public calledByPool {
        require(
            depositsOfByToken(payee, token) >= amount,
            "Not enough tokens to encumber"
        );

        if (!_shouldWithdrawToken[token]) {
            _shouldWithdrawToken[token] = true;
            _tokensToWithdraw.push(token);
        }

        _removeAmount(payee, token, amount);
        _amountToWithdraw[token] += amount;
    }

    /// @dev Withdraw the funds to the specified address.
    function withdraw() public calledByPool {
        for (int256 i = 0; i < int256(_tokensToWithdraw.length); i++) {
            address token = _tokensToWithdraw[uint256(i)];

            require(
                IERC20Minimal(token).transfer(
                    withdrawAddress,
                    _amountToWithdraw[token]
                ),
                "Could not send the moneys"
            );
        }
    }
}
