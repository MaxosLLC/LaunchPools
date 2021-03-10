// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import './Stake.sol';

contract Launchpool is AccessControl, Ownable {
    using SafeMath for uint256;

    // object to interact with Stake.sol
    Stake stakingContract;   

    bool public stakingAllowed;
    bool public commitmentAllowed;
    address[] public stakeholders;
    uint256 public numOfStakeHolders;
    mapping(address => uint256) public stakes;
    bytes32 public constant SPONSOR = keccak256("SPONSOR");

    enum Status {Staking, Committing, Committed, Closed}

    constructor(address _sponsor) {
        _setupRole(SPONSOR, _sponsor);
    }

    /** add stakes to the launch pool */
    function addStakes(uint256 _stake) public {
        stakingContract.stake(_stake);
        if (stakes[msg.sender] == 0) addStakeHolder(msg.sender);
        stakes[msg.sender] = stakes[msg.sender].add(_stake);
    }

    /** remove stakes from the launch pool */
    function removeStakes(uint256 _stake) public {
        // safe math throws error code if negative
        stakes[msg.sender] = stakes[msg.sender].sub(_stake);
        if (stakes[msg.sender] == 0) removeStakeHolder(msg.sender);
        stakingContract.unstake(_stake);
    }

    /** retrieve all stakes from the pool */
    function getStakes() public view returns (uint256) {
        uint256 _totalStakes = 0;
        for (uint256 s = 0; s < stakeholders.length; s += 1) {
            // safe math to add
            _totalStakes = _totalStakes.add(stakes[stakeholders[s]]);
        }
        return _totalStakes;
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

    /** set the expiration date for the commitment */
    function setExpirationDate() public {

    }

    /** change the status of the staking process */
    function setStatus(Status _newStatus) onlyOwner() public {
        
    }

    /** if staking status is 'Committed', claim the stakes  */
    function claimStakes() public returns (uint256) {

    }

    /** set the status to 'Closed' and refund all stakes */
    function closeLaunchPool() public returns (bool) {

    }

    function isStakeHolder(address _address) public view returns (bool, uint256) {
        // loop through stakeholders and if address exists then return true and index
        for (uint256 s = 0; s < stakeholders.length; s += 1) {
            if (_address == stakeholders[s]) return (true, s);
        }
        return (false, 0);
    }

    /** check if stakeholder already is in array before pushing in new address */
    function addStakeHolder(address _stakeholder) public {
        (bool _isStakeHolder, ) = isStakeHolder(_stakeholder);
        if (!_isStakeHolder) stakeholders.push(_stakeholder);
        numOfStakeHolders = stakeholders.length;
    }

    function removeStakeHolder(address _stakeholder) public {
        (bool _isStakeHolder, uint256 s) = isStakeHolder(_stakeholder);
        if (_isStakeHolder) {
            // if stake holder exists
            // set stakeholders at index s to the last value in the array and pop (remove last value)
            stakeholders[s] = stakeholders[stakeholders.length - 1];
            stakeholders.pop();
        }
        numOfStakeHolders = stakeholders.length;
    }

    /** find stake size of specific stake holder */ 
    function stakeOf(address _stakeholder) public view returns (uint256) {
        return stakes[_stakeholder];
    }

}
