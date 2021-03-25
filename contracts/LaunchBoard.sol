// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LaunchPool.sol";

contract LaunchBoard is AccessControl, Ownable {
    using SafeMath for uint256;

    mapping(address => LaunchPool) LaunchPools;

    //allowed token address
    address token;
    bytes32 public constant SPONSOR = keccak256("SPONSOR");

    enum PoolState {Open, Closed}
    // default state
    PoolState poolState = PoolState.Open;

    event LaunchPoolCreated(address sponsor, string pool);
    event PoolStatusChanged(bytes32 poolName, PoolState newStatus);

    constructor() {
        //grantRole(SPONSOR, _sponsor);
        //token = _allowedToken;
    }

    function createLaunchPool(string memory _poolName, string memory _homeUrl, uint256 _expiration,
        uint256 _minCommitment, uint256 _maxCommitment) onlyOwner() public {

        LaunchPools[msg.sender] = new LaunchPool(_poolName, _homeUrl, _expiration, _minCommitment, _maxCommitment);
        emit LaunchPoolCreated(msg.sender, _poolName);
    }

    //======== HELPER FUNCTIONS ========

    /** change the status of a launch pool */
    function updatePoolState(bytes32 _poolName, PoolState _newState) 
                public onlyOwner() {
        require(_newState > poolState);
        poolState = _newState;
        emit PoolStatusChanged(_poolName, poolState);
    }
}