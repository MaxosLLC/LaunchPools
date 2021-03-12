// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Stake is Ownable {

    using SafeMath for uint256;

    address token;
    uint256 private minStakeValue;
    uint256 private count;
    uint256[] public order;

    mapping(address => uint256) stakeholders;
    mapping(address => bool) public sponsors;

    event NotifyStaked(address staker, uint256 amount, uint256 position);
    event NotifyUnstaked(address staker, uint256 amount, uint256 position);

    //exclusive access for sponsors
    modifier onlySponsor(address _sponsor) {
        require(sponsors[_sponsor] == true, "You must be a sponsor");
        _;
    }

    constructor(address _token) {
        token = _token;
    }

    //====== Functions for Investors ======//

    /** stake a token in a pool */
    function stake(uint256 _value) public {
        require(stakeholders[msg.sender] >= minStakeValue, "Amount to is less than minimum stake value");
        IERC20(token).transferFrom(msg.sender, address(this), _value);
        stakeholders[msg.sender] = stakeholders[msg.sender].add(_value);
        count = count + 1;
        order.push(count);
        emit NotifyStaked(msg.sender, _value, count);
    }

    /** unstake a token from the pool */
    function unstake(uint256 _value) public {
        require(stakeholders[msg.sender] >= _value, "Amount to unstake exceeds sender's staked amount");
        IERC20(token).transfer(msg.sender, _value);
        stakeholders[msg.sender] = stakeholders[msg.sender].sub(_value);
        count = count - 1;
        order.push(count);
        emit NotifyUnstaked(msg.sender, _value, count);
    }

    /** @dev get the amount of tokens staked in a pool */
    function getAmount(address _stakeholder) public view returns (uint256) {
        return stakeholders[_stakeholder];
    }

    //====== Functions for Sponsors/Administrators ======//

    /** set the minimum value that can be staked */
    function setMinimumStakeValue(uint _minValue) external onlySponsor(msg.sender) onlyOwner() {
        minStakeValue = _minValue;
    }

    //====== Payable Fallback Functions ======//

    /** @dev payable fallback
     * it is assumed that only funds received will be from the contract
     */
    fallback() external payable {
        revert();
    }

    /** @dev another payable fallback
     * required by the solidity compiler
     */
    receive() external payable {
        revert();
    }

}