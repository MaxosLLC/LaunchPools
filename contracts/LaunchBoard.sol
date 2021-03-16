// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LaunchPool.sol";

contract LaunchBoard is AccessControl, Ownable, LaunchPool {
    using SafeMath for uint256;

    //allowed token address
    address token;
    bytes32 public constant SPONSOR = keccak256("SPONSOR");

    enum PoolState {Open, Closed}
    // default state
    PoolState poolState = PoolState.Open;

    event LaunchPoolCreated(address sponsor, bytes32 pool);
    event PoolStatusChanged(bytes32 poolName, PoolState newStatus);

    constructor(address _sponsor, address _allowedToken) {
        //grantRole(SPONSOR, _sponsor);
        token = _allowedToken;
    }

    function createLaunchPool(string _poolName, string _homeUrl, uint256 _expiration,
        uint256 _minCommitment, uint256 _maxCommitment) 
                public onlySponsor(_poolName) onlyOwner() correctPool(_poolName) {
        emit LaunchPoolCreated(msg.sender, _poolName);
    }

    function getLaunchPools() public view returns (bytes32[] memory) {
        require(allPools.length > 0, "There are currently no pools");
        return allPools;
    }

    //======== HELPER FUNCTIONS ========

    /** change the status of a launch pool */
    function updatePoolState(bytes32 _poolName, PoolState _newState) 
                public onlySponsor(_poolName) onlyOwner() correctPool(_poolName) {
        require(_newState > poolState);
        poolState = _newState;
        emit PoolStatusChanged(_poolName, poolState);
    }
}