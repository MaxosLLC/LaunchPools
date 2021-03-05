// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Stake.sol";

contract LaunchPool is Ownable {
    
    string public name;
    string public homeUrl;
    //uint256 public date;
    uint256 public count;
    bool public stakingAllowed;
    bool public commitmentAllowed;
    uint256 public maxCommitment;
    uint256 public minCommitment;
    address public investmentAddress;

    mapping(address => Stake) public stakes;

    // The various stages of the staking process
    enum Status {Staking, Committing, Committed, Closed}
        // Phase can take only 0, 1, 2, 3 values: Others invalid

    // Default status
    Status public status = Status.Staking;

    function closeLaunchPool() public {

    }

    function setExpirationDate() public {

    }

    function setCommitment() public {

    }

    function getStakes() public {

    }
}
