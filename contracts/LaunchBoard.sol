// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./LaunchPool.sol";

contract LaunchBoard is Ownable {

  mapping(address => LaunchPool) LaunchPools;

  event LaunchPoolCreated(address launchPool);

  function CreateLaunchPool(string memory _name) onlyOwner public {

    //emit LaunchPoolCreated(address);
  }

}
