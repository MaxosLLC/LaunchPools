// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./interfaces/IERC20Minimal.sol";
import "hardhat/console.sol";

contract StakeVault {
    address private _poolContract;

    uint256 public totalDeposited;

    mapping(address => mapping(address => uint256)) private _deposits;
    mapping(address => uint256) private _depositsByAccount;

    modifier calledByPool() {
        require(_poolContract != address(0), "pool contract not set");
        require(_poolContract == msg.sender, "sender is not the pool contract");
        _;
    }

    function setPoolContract(address poolContract) public {
        _poolContract = poolContract;
    }

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

    function withdrawStake(
        address token,
        uint256 amount,
        address payee
    ) public calledByPool {
        require(
            amount <= _depositsByAccount[payee],
            "Player has less than requested amount"
        );

        totalDeposited -= amount;
        _depositsByAccount[payee] -= amount;
        _deposits[payee][token] -= amount;

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
}
