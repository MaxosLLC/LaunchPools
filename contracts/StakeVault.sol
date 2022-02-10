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

    struct LeadInvestor {
        address investor;
        bool isStaked;
    }

    struct DealInfo {
        string name;
        string url;
        address sponsor;
        address stakingToken;
        uint256 startBonus;
        uint256 endBonus;
        uint256 preSaleAmount;
        uint256 minSaleAmount;
        uint256 maxSaleAmount;
        uint256[] stakeIds;
        LeadInvestor lead;
        DealPrice dealPrice;
        DealStatus status;
    }
    
    uint256 public offerPeriod;
    uint256[] private dealIds; 
    enum DealStatus { NotDisplaying, Staking, Offering, Delivering, Claiming, Closed }
    enum DisplayStatus { All, List, Item }

    Counters.Counter private _dealIds;
    Counters.Counter private _stakeIds;

    mapping (uint256 => StakeInfo) public stakeInfo;
    mapping (uint256 => DealInfo) public dealInfo;
    mapping (address => bool) public allowedTokenList;
    mapping (address => uint256[]) private stakesByInvestor;
    mapping (address => uint256[]) private dealsBySponsor;

    event AddDeal(uint256, address);
    event UpdateDeal(uint256, address);
    event SetDealPrice(uint256, address);
    event UpdateDealPrice(uint256, address);
    event Deposit(uint256, uint256, address);
    event Withdraw(uint256, uint256, address);
    event Claim(uint256, uint256, address);

    constructor(address _token, uint256 _offerPeriod) {
        offerPeriod = _offerPeriod;
        allowedTokenList[_token] = true;
    }

    modifier allowedToken(address _token) {
        require(allowedTokenList[_token], "The staking token is not allowed");
        _;
    }

    modifier existDeal(uint256 _dealId) {
        require(_dealId <= _dealIds.current(), "The Deal is not exist.");
        _;
    }

    function addDeal(
        string memory _name,
        string memory _url,
        address _leadInvestor,
        uint256 _startBonus,
        uint256 _endBonus,
        uint256 _preSaleAmount,
        uint256 _minSaleAmount,
        uint256 _maxSaleAmount,
        address _stakingToken
    ) public allowedToken(_stakingToken) {
        _dealIds.increment();
        uint256 dealId = _dealIds.current();
        dealIds.push(dealId);
        dealsBySponsor[msg.sender].push(dealId);
        DealInfo storage deal = dealInfo[dealId];
        deal.name = _name;
        deal.url = _url;
        deal.lead.investor = _leadInvestor;
        deal.startBonus = _startBonus;
        deal.endBonus = _endBonus;
        deal.preSaleAmount = _preSaleAmount;
        deal.minSaleAmount = _minSaleAmount;
        deal.maxSaleAmount = _maxSaleAmount;
        deal.sponsor = msg.sender;
        deal.stakingToken = _stakingToken;
        updateDealStatus(dealId, DealStatus.NotDisplaying);

        emit AddDeal(dealId, msg.sender);
    }

    function updateDeal(
        uint256 _dealId,
        address _leadInvestor,
        uint256 _startBonus,
        uint256 _endBonus,
        uint256 _preSaleAmount,
        address _stakingToken
    ) public allowedToken(_stakingToken) {
        DealInfo storage deal = dealInfo[_dealId];
        require(deal.sponsor == msg.sender, "Only sponsor can update the deal.");
        require(deal.status == DealStatus.NotDisplaying || deal.status == DealStatus.Staking, "The deal status should be NotDisplaying or Staking.");
        require(deal.stakeIds.length < 1, "The deal should be empty.");
        deal.lead.investor = _leadInvestor;
        deal.startBonus = _startBonus;
        deal.endBonus = _endBonus;
        deal.preSaleAmount = _preSaleAmount;
        deal.stakingToken = _stakingToken;

        emit UpdateDeal(_dealId, msg.sender);
    }

    function updateDealStatus(
        uint256 _dealId,
        DealStatus _status
    ) public {
        DealInfo storage deal = dealInfo[_dealId];
        require(deal.sponsor == msg.sender || owner() == msg.sender, "You have no permission to update deal status.");
        require(deal.status != DealStatus.Closed, "You can not change status when the deal status is Closed.");

        if(_status == DealStatus.NotDisplaying) {
            require(deal.stakeIds.length < 1, "Set NotDisplaying: The deal should not have a stake.");
        } else if(_status == DealStatus.Staking) {
            require(deal.status < DealStatus.Delivering, "Set Staking: The deal status should not be Delivering, Claiming, Closed.");
        } else if(_status == DealStatus.Offering) {
            require(deal.status < DealStatus.Offering, "Set Offering: The deal status should be Staking.");
        } else if(_status == DealStatus.Delivering) {
            require(deal.status == DealStatus.Offering, "Set Delivering: The deal status should be Offering.");
            
            uint256[] memory stakeIds = deal.stakeIds;
            uint256 stakedAmount;
            for(uint256 i=0; i<stakeIds.length; i++) {
                StakeInfo storage stake = stakeInfo[stakeIds[i]];
                stakedAmount = stakedAmount.add(stake.amount);
            }
            require(deal.minSaleAmount <= stakedAmount, "Set Delivering: The staked amount should be over minSaleAmount.");

            if(owner() != msg.sender) {
                require(deal.dealPrice.startDate.add(offerPeriod) < block.timestamp, "Set Delivering: The sponsor cannot set status as a Delivering until 7 days after post a deal price.");
            }
        } else if(_status == DealStatus.Claiming) {
            require(owner() == msg.sender && deal.status == DealStatus.Delivering, "Set Claiming: Only owner can set Claiming status when the deal status is Delivering.");
        } else if(_status != DealStatus.Closed) {
            revert("You cannot change the deal status.");
        }
        
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
        updateDealStatus(_dealId, DealStatus.Offering);
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
        require(deal.status == DealStatus.Offering, "The deal status should be Offering.");
        deal.dealPrice.updateDate = block.timestamp;
        deal.dealPrice.price = _price;

        emit UpdateDealPrice(_dealId, msg.sender);
    }

    function deposite(
        uint256 _dealId,
        uint256 _amount
    ) public existDeal(_dealId) {
        require(checkDealStatus(_dealId, DealStatus.NotDisplaying) || checkDealStatus(_dealId, DealStatus.Staking) || checkDealStatus(_dealId, DealStatus.Offering), "The deal status should be NotDisplaying, Staking or Offering.");
        require(_amount > 0, "The deposite amount is not enough.");
        DealInfo storage deal = dealInfo[_dealId];
        require(deal.lead.investor != address(0), "The deal should have a lead investor.");
        if(deal.lead.investor != msg.sender) {
            require(deal.lead.isStaked, "The lead investor should stake at first.");
        } else {
            if(!deal.lead.isStaked) {
                deal.lead.isStaked = true;
            }
        }
        _stakeIds.increment();
        uint256 stakeId = _stakeIds.current();
        address staker = msg.sender;
        StakeInfo storage stake = stakeInfo[stakeId];
        stake.id = stakeId;
        stake.dealId = _dealId;
        stake.staker = staker;
        stake.amount = _amount;
        stakesByInvestor[staker].push(stakeId);
        if(deal.stakeIds.length < 1) {
            deal.status = DealStatus.Staking;
        }
        deal.stakeIds.push(stakeId);
        IERC20(deal.stakingToken).transferFrom(staker, address(this), _amount);

        emit Deposit(_dealId, _amount, staker);
    }

    function withdraw(
        uint256 _stakeId
    ) public {
        StakeInfo storage stake = stakeInfo[_stakeId];
        uint256 _dealId = stake.dealId;
        require(!(checkDealStatus(_dealId, DealStatus.Delivering) && checkDealStatus(_dealId, DealStatus.Claiming)), "The deal status should not be a Delivering or Claiming.");
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
        require(checkDealStatus(_dealId, DealStatus.Claiming), "The deal status should be Claiming.");
        DealInfo storage deal = dealInfo[_dealId];
        require(deal.sponsor == msg.sender, "Must be a sponsor of this deal");
        updateDealStatus(_dealId, DealStatus.Closed);
        
        uint256[] memory stakeIds = deal.stakeIds;
        uint256 claimAmount;
        
        for(uint256 i=0; i<stakeIds.length; i++) {
            StakeInfo storage stake = stakeInfo[stakeIds[i]];
            
            if(!stake.isClaimed) {
                claimAmount = claimAmount.add(stake.amount);
                stake.isClaimed = true;

                if(claimAmount > deal.maxSaleAmount) {
                    uint256 diffAmount = claimAmount.sub(deal.maxSaleAmount);
                    stake.restAmount = diffAmount;
                    stake.amount = stake.amount.sub(diffAmount);
                    claimAmount = deal.maxSaleAmount;
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
    ) public {
        StakeInfo storage stake = stakeInfo[_stakeId];
        DealInfo storage deal = dealInfo[stake.dealId];
        require(deal.status == DealStatus.Closed, "The deal status should be a Closed.");
        require(deal.sponsor == msg.sender || owner() == msg.sender, "You have no permission to send back the staked amount.");
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
        uint256 _amount = stake.amount; // staked amount while in the presale
        
        for(uint256 i=0; i<stakeIds.length; i++) {
            if(_stakeId <= stakeIds[i]) {
                break;
            }
            StakeInfo memory _stake = stakeInfo[stakeIds[i]];
            if(_stake.amount > 0) {
                stakedAmount = stakedAmount.add(_stake.amount);
            }
        }

        if(deal.preSaleAmount < stakedAmount) {
            return 0;
        }

        if(deal.preSaleAmount < stakedAmount.add(_amount)) {
            _amount = deal.preSaleAmount.sub(stakedAmount);
        }

        bonus = deal.startBonus.sub(deal.endBonus).mul(deal.preSaleAmount.sub(stakedAmount).sub(_amount.div(2))).div(deal.preSaleAmount).add(deal.endBonus);

        return bonus;
    }

    function getEstimateBonus(
        uint256 _dealId,
        uint256 _amount
    ) public view returns(uint256) {
        if(_amount <= 0) {
            return 0;
        }

        DealInfo memory deal = dealInfo[_dealId];
        uint256[] memory stakeIds = deal.stakeIds;
        uint256 stakedAmount; // total staked amount in the deal before _staker stake 
        uint256 bonus; // the average bonus of the _staker after staking
        
        for(uint256 i=0; i<stakeIds.length; i++) {
            StakeInfo memory _stake = stakeInfo[stakeIds[i]];
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

    function getDealIds(DisplayStatus _displayStatus, DealStatus _dealStatus) public view returns(uint256[] memory) {
        uint256[] memory filterDealIds = new uint256[](dealIds.length);
        uint256 index = 0;
        
        if(_displayStatus == DisplayStatus.All) {
            return dealIds;
        } else {
            for(uint256 id=0; id<dealIds.length; id++) {
                DealInfo storage deal = dealInfo[id];
                if(_displayStatus == DisplayStatus.List) {
                    if(deal.status != DealStatus.NotDisplaying && deal.status != DealStatus.Closed) {
                        filterDealIds[index] = id;
                        index ++;
                    } 
                } else if(_displayStatus == DisplayStatus.Item) {
                    if(deal.status == _dealStatus) {
                        filterDealIds[index] = id;
                        index ++;
                    } 
                }
            }
        }

        uint256[] memory tmp = new uint256[](index);
        for(uint256 i=0; i<index; i++) {
            tmp[i] = filterDealIds[i];
        }
        return tmp;
    } 

    function getStakes (uint256 _dealId) public view returns(uint256 [] memory) {
        DealInfo storage deal = dealInfo[_dealId];
        return deal.stakeIds;
    }
    
    function getInvetorStakes (address _investor) public view returns(uint256 [] memory) {
        return stakesByInvestor[_investor];
    }
    
    function getSponsorDeals (address _sponsor) public view returns(uint256 [] memory) {
        return dealsBySponsor[_sponsor];
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

    function currentBlockTime() public view returns (uint256) {
        return block.timestamp;
    }
}