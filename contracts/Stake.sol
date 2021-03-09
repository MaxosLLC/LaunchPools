// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Stake is Ownable {

    using SafeMath for uint256;

    address public tokenAddress;

    mapping(address => uint256) stakers;

    event NotifyStaked(address staker, uint256 value);
    event NotifyUnstaked(address staker, uint256 value);

    constructor(address _tokenAddress) {
        tokenAddress = _tokenAddress;
    }

    /** @dev payable fallback
     * it is assumed that only funds received will be from the contract
     */
    fallback() external payable {
        revert();
    }

    receive() external payable {
        revert();
    }

    function stakedAmount(address _staker) public view returns (uint256) {
        return stakers[_staker];
    }

    function stake(uint256 _value) public returns (bool) {
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), _value);
        stakers[msg.sender] = stakers[msg.sender].add(_value);
        emit NotifyStaked(msg.sender, _value);
        return true;
    }
    
    function unstake(uint256 _value) public returns (bool) {
        require(stakers[msg.sender] >= _value, "Amount to unstake exceeds sender's staked amount");
        IERC20(tokenAddress).transfer(msg.sender, _value);
        stakers[msg.sender] = stakers[msg.sender].sub(_value);
        emit NotifyUnstaked(msg.sender, _value);
        return true;
    }
}