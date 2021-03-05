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

    /** @dev address of staking contract
    * this variable is set at construction, and can be changed only by owner.*/
    address private stakeContract;
    /** @dev staking contract object to interact with staking mechanism.
     * this is a mock contract.  */
    Stake private sc;

    /** @dev track total staked amount */
    uint private totalStaked;
    /** @dev track total deposited to pool */
    uint private totalDeposited;

    /** @dev track balances of ether deposited to pool */
    mapping(address => uint) private depositedBalances;
    /** @dev track balances of ether staked */
    mapping(address => uint) private stakedBalances;
    /** @dev track user request to enter next staking period */
    mapping(address => uint) private requestStake;
    /** @dev track user request to exit current staking period */
    mapping(address => uint) private requestUnStake;

    // The various stages of the staking process
    enum Status {Staking, Committing, Committed, Closed}

    event NotifyFallback(address sender, uint amount);
    event NotifyNewSC(address oldSC, address newSC);
    event NotifyDeposit(address sender, uint amount, uint balance);
    event NotifyStaked(address sender, uint amount);
    event NotifyUpdate(address sender, Status newStatus);
    event NotifyWithdrawal(address sender, uint startBal, uint finalBal, uint request);
    event NotifyEarnings(uint earnings);

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
        emit NotifyUpdate(msg.sender, status);
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

    /** @dev retreive current state of users funds
     * @return array of values describing the current state of user
     */
    function getState() validStatus(Status.Closed) external view returns (uint[] calldata) {
        uint[] memory state = new uint[](4);
        state[0] = depositedBalances[msg.sender];
        state[1] = requestStake[msg.sender];
        state[2] = requestUnStake[msg.sender];
        state[3] = stakedBalances[msg.sender];
        return state;
    }

    /** @dev payable fallback
     * it is assumed that only funds received will be from stakeContract 
     */
    fallback() external payable {
        emit NotifyFallback(msg.sender, msg.value);
    }

    receive() external payable {
        emit NotifyFallback(msg.sender, msg.value);
    }
}