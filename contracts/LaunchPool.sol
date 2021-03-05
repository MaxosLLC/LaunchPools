// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Stake.sol";

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

    mapping(address => Stake) public stakes;

    // The various stages of the staking process
    enum Status {Staking, Committing, Committed, Closed}

    // Default status
    Status public status = Status.Staking;

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
     * closes the pool and refunds all stakes
     */
    function closeLaunchPool() public {

    }

    /**
     * sets the expiration date for the commitment
     */
    function setExpirationDate() public {

    }

    /**
     * sets the value to be committed
     */
    function setCommitment() public {

    }

    /**
     * retrieves all stakes from the pool
     */
    function getStakes() public {

    }
}
