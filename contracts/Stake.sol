// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Stake is Ownable {

    using SafeMath for uint256;

    address token;
    address investor;
    address sponsor;
    uint256 value;
    uint256 commitment;
    uint256 order;

    event NotifyStaked(address staker, uint256 amount);
    event NotifyUnstaked(address staker, uint256 amount);
    event NotifyClaimed(address staker, uint256 amount);
    event NotifyClosed(address staker);

    constructor(address _token) {
        token = _token;
    }

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

    /*====== Functions for Administrators ======*/

    /** set the minimum value that can be committed */
    function setMinValue(uint256 _value) onlyOwner() public returns (bool) {

    }

    /*====== Functions for Pool Sponsors ======*/

    function claim(uint256 _value) public returns (uint256) {

    }

    /*====== Functions for Investors that Own a Stake ======*/

    /**  */
    function close() public returns (bool) {

    }

    function setCommitment(uint256 _value) public returns (bool) {

    }

    /*====== Functions for Any User ======*/

    /** @dev get the amount of tokens from the token contract */
    function getAmount(address _token) public view returns (uint256) {

    }

}