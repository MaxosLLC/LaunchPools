// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Stake is Ownable {
    
    uint256 public Order;
    address public StakedToken;
    uint256 public Value;
    uint256 public Commitment;
}
