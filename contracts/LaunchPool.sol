// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import "@openzeppelin/contracts/utils/escrow/Escrow.sol";
import "./interfaces/IERC20Minimal.sol";

contract LaunchPool {
    string public name;
    uint256 public maxCommitment;
    uint256 public minCommitment;

    address private tokenAddress;

    mapping(address => uint256) private _stakes;

    event Staked(address indexed payee, uint256 weiAmount);
    event Unstaked(address indexed payee, uint256 weiAmount);

    constructor(
        address _tokenAddress,
        string memory _poolName,
        uint256 _minCommitment,
        uint256 _maxCommitment
    ) {
        name = _poolName;
        minCommitment = _minCommitment;
        maxCommitment = _maxCommitment;
        tokenAddress = _tokenAddress;
    }

    function stake(uint256 amount) public {
        address payee = msg.sender;
        _stakes[payee] = _stakes[payee] + amount;

        IERC20Minimal(tokenAddress).transferFrom(
            msg.sender,
            address(this),
            amount
        );

        emit Staked(payee, amount);
    }

    function unstake() public {
        uint256 stake_ = _stakes[msg.sender];
        _stakes[msg.sender] = 0;

        IERC20Minimal(tokenAddress).transfer(msg.sender, stake_);

        emit Unstaked(msg.sender, stake_);
    }

    function stakesOf(address payee) public view returns (uint256) {
        return _stakes[payee];
    }
}
