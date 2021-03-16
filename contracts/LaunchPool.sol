// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import './Stake.sol';

contract LaunchPool is Ownable {
    using SafeMath for uint256;

    // object to interact with Stake.sol
    Stake stakingContract;   

    struct Pool {
        bytes32 name;
        uint256 totalStakes;
    }

    bytes32[] public allPools;
    address[] public stakeholders;
    uint256 public numOfStakeHolders;

    string public name;
    string public homeUrl;
    uint256 public date;
    uint256 public count;
    bool public stakingAllowed;
    bool public commitmentAllowed;
    uint256 public maxCommitment;
    uint256 public minCommitment;
    address public investmentAddress;
    
    mapping(address => Pool) public pools;
    mapping(address => uint256) public stakes;
    mapping(address => uint256) public toBeCommitted;
    mapping(address => uint256) public commitments;

    enum Status {Staking, Committing, Committed, Closed}
    // set default status to `Staking`
    Status public status = Status.Staking;

    event StatusChanged(Status newStatus);
    event StakesClaimed(address owner, uint256 startBal, uint256 finalBal, uint256 amount);

    //exclusive access for sponsors
    modifier onlySponsor(bytes32 _poolName) {
        require(pools[msg.sender].name == _poolName, "You must be a sponsor");
        _;
    }
    //ensure that you're staking in the right pool
    modifier correctPool(bytes32 _poolName) {
        for (uint256 i = 0; i < allPools.length; i += 1) {
            if (allPools[i] == _poolName) delete allPools[i];
            else {
                allPools.push(_poolName);
            }
        }
        _;
    }

    /** add stakes to the launch pool */
    function addStakes(uint256 _stake, bytes32 _poolName) public correctPool(_poolName) {
        require(status == Status.Staking);
        stakingContract.stake(_stake);
        if (stakes[msg.sender] == 0) _addStakeHolder(msg.sender);
        stakes[msg.sender] = stakes[msg.sender].add(_stake);

    }

    /** remove stakes from the launch pool */
    function removeStakes(uint256 _stake) public {
        require(status == Status.Staking || status == Status.Closed);
        // safe math throws error code if negative
        stakes[msg.sender] = stakes[msg.sender].sub(_stake);
        if (stakes[msg.sender] == 0) _removeStakeHolder(msg.sender);
        stakingContract.unstake(_stake);
    }

    /** if staking status is 'Committed', claim the stakes  */
    function claimStakes(uint256 _amount, bytes32 _poolName) external onlySponsor(_poolName) {
        require(status == Status.Committed);
        require(_amount > 0);
        require(commitments[msg.sender] >= _amount);
        uint256 startBalance = commitments[msg.sender];
        commitments[msg.sender] = commitments[msg.sender].sub(_amount);

        msg.sender.transfer(_amount);
        emit StakesClaimed(msg.sender, startBalance, commitments[msg.sender], _amount);
    }

    function setCommitment(uint256 _amount) public {
        require(status == Status.Staking);
        uint256 _commit = stakes[msg.sender].sub(_amount);
        toBeCommitted[msg.sender] = toBeCommitted[msg.sender].add(_commit);
        status = Status.Committing;
    }

    function commitValue(uint256 _amount) public {
        require(status == Status.Committing);
        uint256 _value = toBeCommitted[msg.sender].sub(_amount);
        commitments[msg.sender] = commitments[msg.sender].add(_value);
        status = Status.Committed;
    }

    /** retrieve all stakes from the pool */
    function getStakes() public view returns (uint256) {
        uint256 _totalStakes = 0;
        for (uint256 s = 0; s < stakeholders.length; s += 1) {
            // safe math to add
            _totalStakes = _totalStakes.add(stakes[stakeholders[s]]);
        }
        return _totalStakes;
    }

    // TODO
    /** set the expiration date for the commitment 
    function setExpirationDate() public {

    }
    */

    /** change the status of the staking process */
    function setStatus(Status _newStatus, bytes32 _poolName) public onlySponsor(_poolName) onlyOwner() {
        require(_newStatus > status);
        status = _newStatus;
        emit StatusChanged(status);
    }

    /** set the status to 'Closed' and refund all stakes */
    function closeLaunchPool(bytes32 _poolName) public onlySponsor(_poolName) onlyOwner() {
        require(status != Status.Committed && status != Status.Committing);
        status = Status.Closed;
        removeStakes(getStakes());
    }

    function isStakeHolder(address _address) public view returns (bool, uint256) {
        // loop through stakeholders and if address exists then return true and index
        for (uint256 s = 0; s < stakeholders.length; s += 1) {
            if (_address == stakeholders[s]) return (true, s);
        }
        return (false, 0);
    }

    /** check if stakeholder already is in array before pushing in new address */
    function _addStakeHolder(address _stakeholder) private {
        (bool _isStakeHolder, ) = isStakeHolder(_stakeholder);
        if (!_isStakeHolder) stakeholders.push(_stakeholder);
        numOfStakeHolders = stakeholders.length;
    }

    function _removeStakeHolder(address _stakeholder) private {
        (bool _isStakeHolder, uint256 s) = isStakeHolder(_stakeholder);
        if (_isStakeHolder) {
            // if stake holder exists
            // set stakeholders at index s to the last value in the array and pop (remove last value)
            stakeholders[s] = stakeholders[stakeholders.length - 1];
            stakeholders.pop();
        }
        numOfStakeHolders = stakeholders.length;
    }

    /** find stake size of specific stake holder */ 
    function stakeOf(address _stakeholder) public view returns (uint256) {
        return stakes[_stakeholder];
    }

    /** @dev payable fallback
     * it is assumed that only funds received will be from the contract
     */
    fallback() external payable {
        revert();
    }

    /** @dev another payable fallback
     * required by the solidity compiler
     */
    receive() external payable {
        revert();
    }

    /** Internal helper function to help create launch pools in LaunchBoard.sol */
    function _createLaunchPools(bytes32 _poolName) internal onlySponsor(_poolName) onlyOwner() {

    }
}
