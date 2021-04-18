// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FakeUNI is ERC20 {
  constructor() ERC20("FakeUNI", "fUNI") {
  }
}
