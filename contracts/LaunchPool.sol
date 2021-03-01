// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./ownership/Ownable.sol";
import "./Stake.sol";

contract LaunchPool is Ownable {
    
    string public Name;
    string public HomeUrl;
    uint256 public Date;
    uint256 public Count;
    bool public StakingAllowed;
    bool public CommitmentAllowed;
    uint256 public MaxCommitment;
    uint256 public MinCommitment;
    address public InvestmentAddress;
    uint256 public Status;

    mapping(Stake => address) Stakes;
}
