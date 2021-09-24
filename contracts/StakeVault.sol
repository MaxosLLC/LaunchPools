// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract StakeVault is Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    struct StakeInfo {
        uint256 id;
        uint256 dealId;
        address staker;
        uint256 amount;
        uint256 restAmount;
        bool isClaimed;
    }

    struct DealPrice {
        uint256 price;
        uint256 startDate;
        uint256 updateDate;
    }

    struct DealInfo {
        string name;
        string url;
        address sponsor;
        address stakingToken;
        uint256 startBonus;
        uint256 endBonus;
        uint256 preSaleAmount;
        uint256 openSaleAmount;
        uint256[] stakeIds;
        DealPrice dealPrice;
        DealStatus status;
    }
    
    uint256 public offerPeriod; 
    enum DealStatus { NotDisplaying, Staking, Offering, Delivering, Claiming, Closed }

    Counters.Counter private _dealIds;
    Counters.Counter private _stakeIds;

    mapping (uint256 => StakeInfo) public stakeInfo;
    mapping (address => uint256[]) public stakesByInvestor;
    mapping (uint256 => DealInfo) public dealInfo;
    mapping (address => bool) public allowedTokenList;

    event AddDeal(uint256, address);
    event SetDealPrice(uint256, address);
    event UpdateDealPrice(uint256, address);
    event Deposit(uint256, uint256, address);
    event Withdraw(uint256, uint256, address);
    event Claim(uint256, uint256, address);

    constructor() {
        offerPeriod = 604800; // default is 7 days
        address defaultToken = 0xeb8f08a975Ab53E34D8a0330E0D34de942C95926; // USDC on the Rinkeby testnet
        allowedTokenList[defaultToken] = true;
    }

    modifier existDeal(uint256 _dealId) {
        require(_dealId <= _dealIds.current(), "The Deal is not exist.");
        _;
    }

    function addDeal(
        string memory _name,
        string memory _url,
        uint256 _startBonus,
        uint256 _endBonus,
        uint256 _preSaleAmount,
        uint256 _openSaleAmount,
        address _stakingToken
    ) public {
        _dealIds.increment();
        uint256 dealId = _dealIds.current();
        DealInfo storage deal = dealInfo[dealId];

        deal.name = _name;
        deal.url = _url;
        deal.startBonus = _startBonus;
        deal.endBonus = _endBonus;
        deal.preSaleAmount = _preSaleAmount;
        deal.openSaleAmount = _openSaleAmount;
        deal.sponsor = msg.sender;
        deal.stakingToken = _stakingToken;
        deal.status = DealStatus.Staking;

        emit AddDeal(dealId, msg.sender);
    }

    function updateDealStatus(
        uint256 _dealId,
        DealStatus _status
    ) public onlyOwner {
        DealInfo storage deal = dealInfo[_dealId];
        deal.status = _status;
    }

    function checkDealStatus(
        uint256 _dealId,
        DealStatus _status
    ) public view existDeal(_dealId) returns(bool) {
        DealInfo storage deal = dealInfo[_dealId];
        return deal.status == _status;
    }

    function setDealPrice(
        uint256 _dealId,
        uint256 _price
    ) public existDeal(_dealId) {
        DealInfo storage deal = dealInfo[_dealId];
        require(deal.sponsor == msg.sender, "Only sponsor can set the price");
        deal.status = DealStatus.Offering;
        deal.dealPrice.price = _price;
        deal.dealPrice.startDate = block.timestamp;

        emit SetDealPrice(_dealId, msg.sender);
    }

    function updateDealPrice(
        uint256 _dealId,
        uint256 _price
    ) public existDeal(_dealId) {
        DealInfo storage deal = dealInfo[_dealId];
        require(deal.sponsor == msg.sender, "Only sponsor can set the price");
        deal.status = DealStatus.Offering;
        deal.dealPrice.updateDate = block.timestamp;
        deal.dealPrice.price = _price;

        emit UpdateDealPrice(_dealId, msg.sender);
    }

    function deposite(
        uint256 _dealId,
        uint256 _amount
    ) public existDeal(_dealId) {
        require(checkDealStatus(_dealId, DealStatus.Staking) || checkDealStatus(_dealId, DealStatus.Offering), "Can't deposite in this deal");
        _stakeIds.increment();
        uint256 stakeId = _stakeIds.current();
        address staker = msg.sender;
        DealInfo storage deal = dealInfo[_dealId];
        StakeInfo storage stake = stakeInfo[stakeId];
        stake.id = stakeId;
        stake.dealId = _dealId;
        stake.staker = staker;
        stake.amount = _amount;
        stakesByInvestor[staker].push(stakeId);
        deal.stakeIds.push(stakeId);

        IERC20(deal.stakingToken).transferFrom(staker, address(this), _amount);

        emit Deposit(_dealId, _amount, staker);
    }

    function withdraw(
        uint256 _stakeId
    ) public {
        StakeInfo storage stake = stakeInfo[_stakeId];
        uint256 _dealId = stake.dealId;
        require(!(checkDealStatus(_dealId, DealStatus.Delivering) && checkDealStatus(_dealId, DealStatus.Claiming)), "Can't withdraw in this deal");
        require(stake.staker == msg.sender, "Must be a staker");
        require(stake.amount > 0, "The withdraw amount is not enough.");
        DealInfo storage deal = dealInfo[_dealId];
        uint256 _amount = stake.amount;
        stake.amount = 0;
        IERC20(deal.stakingToken).transfer(msg.sender, _amount);

        emit Withdraw(_dealId, _amount, msg.sender);
    }

    function claim(
        uint256 _dealId
    ) external {
        require(checkDealStatus(_dealId, DealStatus.Claiming), "Can't claim from this deal");
        DealInfo storage deal = dealInfo[_dealId];
        require(deal.sponsor == msg.sender, "Must be a staker");
        uint256[] memory stakeIds = deal.stakeIds;
        uint256 claimAmount;
        
        for(uint256 i=0; i<stakeIds.length; i++) {
            StakeInfo storage stake = stakeInfo[stakeIds[i]];
            
            if(!stake.isClaimed) {
                claimAmount = claimAmount.add(stake.amount);
                stake.isClaimed = true;

                if(claimAmount > deal.preSaleAmount) {
                    uint256 diffAmount = claimAmount.sub(deal.preSaleAmount);
                    stake.restAmount = diffAmount;
                    stake.amount = stake.amount.sub(diffAmount);
                    claimAmount = deal.preSaleAmount;
                    break;
                } else {
                    stake.amount = 0;
                }
            }
        }

        IERC20(deal.stakingToken).transfer(msg.sender, claimAmount);

        emit Claim(_dealId, claimAmount, msg.sender);
    }

    function sendBack(
        uint256 _stakeId
    ) public onlyOwner {
        StakeInfo storage stake = stakeInfo[_stakeId];
        DealInfo storage deal = dealInfo[stake.dealId];
        require(stake.amount > 0, "The withdraw amount is not enough.");
        uint256 _amount = stake.amount;
        stake.amount = 0;
        IERC20(deal.stakingToken).transfer(stake.staker, _amount);
    }

    function getBonus(
        uint256 _stakeId
    ) public view returns(uint256) {
        StakeInfo memory stake = stakeInfo[_stakeId];
        DealInfo memory deal = dealInfo[stake.dealId];
        uint256[] memory stakeIds = deal.stakeIds;
        uint256 stakedAmount; // total staked amount in the deal before _staker stake 
        uint256 bonus; // the average bonus of the _staker after staking
        uint256 _amount = stake.amount.div(stake.restAmount); // staked amount while in the presale
        
        for(uint256 i=stakeIds[0]; i<_stakeId; i++) {
            StakeInfo memory _stake = stakeInfo[i];
            if(_stake.amount > 0) {
                stakedAmount = stakedAmount.add(_stake.amount);
            }
        }

        if(deal.preSaleAmount < stakedAmount.add(_amount.div(2))) {
            return 0;
        }

        bonus = deal.startBonus.sub(deal.endBonus).mul(deal.preSaleAmount.sub(stakedAmount).sub(_amount.div(2))).div(deal.preSaleAmount).add(deal.endBonus);

        return bonus;
    }

    function addAllowedToken(
        address _token
    ) public onlyOwner {
        allowedTokenList[_token] = true;
    }

    function isAllowedToken(
        address _token
    ) public view returns(bool) {
        return allowedTokenList[_token];
    }
}