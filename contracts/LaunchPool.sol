// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import './Stake.sol';

contract LaunchPool is Ownable {
    
    string public name;
    string public homeUrl;
    uint256 public date;
    uint256 public count;
    bool public stakingAllowed;
    bool public commitmentAllowed;
    uint256 public maxCommitment;
    uint256 public minCommitment;
    address public investmentAddress;

    mapping(address => Stake) allStakes;

    // The various stages of the staking process
    enum Status {Staking, Committing, Committed, Closed}

    // Default status
    Status public status = Status.Staking;

    // modifiers
    modifier validStatus(Status reqStatus) {
        require(status == reqStatus);
        _;
    }

    /**
     * @dev Sets the initial values
     */
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
            
        //set initial state variables
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

    /**
     * changes the status of the staking process
     */
    function setCommitment(Status _newStatus) public {
        require(_newStatus > status);
        status = _newStatus;
        // add logic
    }

    /**
     * closes the pool and refunds all stakes
     */
    function closeLaunchPool() validStatus(Status.Closed) public {

    }

    /**
     * sets the expiration date for the commitment
     */
    function setExpirationDate() public {

    }

    /**
     * retrieves all stakes from the pool
     */
    function getStakes() validStatus(Status.Closed) public {

    }
}