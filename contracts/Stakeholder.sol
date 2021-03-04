// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

abstract contract Stakeholder {
    address public stakeholderRewards;

    function notifyRewardAmount(uint256 reward) virtual external;

    modifier onlyStakeholder() {
        require(msg.sender == stakeholderRewards, "Caller is not Stakeholder contract");
        _;
    }
}
