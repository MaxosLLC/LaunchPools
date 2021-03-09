// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import './Stake.sol';

contract Launchpool is Ownable {
    
    string public name;
    string public homeUrl;
    uint256 public date;
    uint256 public count;
    bool public stakingAllowed;
    bool public commitmentAllowed;
    uint256 public maxCommitment;
    uint256 public minCommitment;
    address public investmentAddress;

    mapping(address => Stake) stakes;

    enum Status {Staking, Committing, Committed, Closed}

    /** @dev sets the initial values */
    constructor(
        string memory _name,
        string memory _homeUrl,
        uint256 _date,
        uint256 _count,
        bool _stakingAllowed,
        bool _commitmentAllowed,
        uint256 _maxCommitment,
        uint256 _minCommitment,
        address _investmentAddress) {

        name = _name;
        homeUrl = _homeUrl;
        date = _date;
        count = _count;
        stakingAllowed = _stakingAllowed;
        commitmentAllowed = _commitmentAllowed;
        maxCommitment = _maxCommitment;
        minCommitment = _minCommitment;
        investmentAddress = _investmentAddress;
    }

    /*====== FUNCTIONS FOR POOL SPONSORS ======*/

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

    /*====== FUNCTIONS FOR INVESTORS ======*/

    /** stake a token in a pool */
    function addStake(address token, uint256 amount) public returns (bool) {

    }

    /** unstake a token from the pool */
    function unStake(address token, uint256 amount) public returns (bool) {

    }

    /** retrieve all stakes from the pool */
    function getStakes(address investor) public {

    }

    /*====== FUNCTIONS FOR ANY USER ======*/
    
    /** retrieve all stakes from the pool */
    function getStakes() public {

    }

    /** retrieves all stakes belonging to a launch pool */
    function getStatistics() public view {

    }

    /** closes the pool and refunds all stakes if expiration date is passed */
    function closePool() public {

    }

}