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

    struct DealAmount {
        uint256 preSale;
        uint256 minSale;
        uint256 maxSale;
    }

    struct DealBonus {
        uint256 start;
        uint256 end;
    }

    struct DealInfo {
        string name;
        string url;
        address sponsor;
        address stakingToken;
        uint256 offerPeriod;
        uint256[] stakeIds;
        DealBonus bonus;
        DealAmount amount;
        LeadInvestor lead;
        DealPrice dealPrice;
        DealStatus status;
    }

    bool public closeAll = false;
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

    event AddDeal(uint256 indexed dealId, address sponsor);
    event UpdateDeal(uint256 indexed dealId, address sponsor);
    event SetDealPrice(uint256 indexed dealId, address sponsor);
    event UpdateDealPrice(uint256 indexed dealId, address sponsor);
    event Deposit(uint256 indexed stakeId, uint256 amount, address investor);
    event Withdraw(uint256 indexed stakeId, uint256 amount, address investor);
    event Claim(uint256 indexed dealId, uint256 amount, address sponsor);

    constructor(address _token) {
        allowedTokenList[_token] = true;
    }

    modifier allowedToken(address _token) {
        require(allowedTokenList[_token], "Not Allowed.");
        _;
    }

    modifier existDeal(uint256 _dealId) {
        require(_dealId <= _dealIds.current(), "Not Exist.");
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
        uint256 _offerPeriod,
        address _stakingToken
    ) external allowedToken(_stakingToken) {
        require(!closeAll, "Closed.");
        _dealIds.increment();
        uint256 dealId = _dealIds.current();
        dealIds.push(dealId);
        dealsBySponsor[msg.sender].push(dealId);
        DealInfo storage deal = dealInfo[dealId];
        deal.name = _name;
        deal.url = _url;
        deal.lead.investor = _leadInvestor;
        deal.bonus.start = _startBonus;
        deal.bonus.end = _endBonus;
        deal.amount.preSale = _preSaleAmount;
        deal.amount.minSale = _minSaleAmount;
        deal.amount.maxSale = _maxSaleAmount;
        deal.offerPeriod = _offerPeriod;
        deal.sponsor = msg.sender;
        deal.stakingToken = _stakingToken;

        if(_leadInvestor != address(0)) {
            deal.status = DealStatus.NotDisplaying;
        } else {
            deal.status = DealStatus.Staking;
        }

        emit AddDeal(dealId, msg.sender);
    }

    function updateDeal(
        uint256 _dealId,
        address _leadInvestor,
        uint256 _startBonus,
        uint256 _endBonus,
        uint256 _preSaleAmount,
        address _stakingToken
    ) external allowedToken(_stakingToken) {
        require(!closeAll, "Closed.");
        DealInfo storage deal = dealInfo[_dealId];
        require(deal.sponsor == msg.sender, "Must Sponsor.");
        require(deal.status == DealStatus.NotDisplaying || deal.status == DealStatus.Staking, "Wrong Status.");
        require(deal.stakeIds.length < 1, "Stake Exist.");
        deal.lead.investor = _leadInvestor;
        deal.bonus.start = _startBonus;
        deal.bonus.end = _endBonus;
        deal.amount.preSale = _preSaleAmount;
        deal.stakingToken = _stakingToken;

        if(_leadInvestor != address(0)) {
            if(deal.status != DealStatus.NotDisplaying) {
                deal.status = DealStatus.NotDisplaying;
            }
        } else {
            if(deal.status != DealStatus.Staking) {
                deal.status = DealStatus.Staking;
            }
        }

        emit UpdateDeal(_dealId, msg.sender);
    }

    function updateDealStatus(
        uint256 _dealId,
        DealStatus _status
    ) external {
        require(!closeAll, "Closed");
        DealInfo storage deal = dealInfo[_dealId];
        require(deal.sponsor == msg.sender || owner() == msg.sender, "No Permission.");
        require(deal.status != DealStatus.Closed, "Wrong Status.");

        if(_status == DealStatus.NotDisplaying) {
            require(deal.stakeIds.length < 1, "Stake Exist.");
        } else if(_status == DealStatus.Staking) {
            require(deal.status < DealStatus.Delivering, "Wrong Status.");
        } else if(_status == DealStatus.Offering) {
            require(deal.status < DealStatus.Offering, "Wrong Status.");
        } else if(_status == DealStatus.Delivering) {
            require(deal.status == DealStatus.Offering, "Wrong Status.");
            
            uint256[] memory stakeIds = deal.stakeIds;
            uint256 stakedAmount;
            for(uint256 i=0; i<stakeIds.length; i++) {
                StakeInfo memory stake = stakeInfo[stakeIds[i]];
                stakedAmount = stakedAmount.add(stake.amount);
            }
            require(deal.amount.minSale <= stakedAmount, "Not Enough.");

            if(owner() != msg.sender) {
                require(deal.dealPrice.startDate.add(deal.offerPeriod) < block.timestamp, "Period Error");
            }
        } else if(_status == DealStatus.Claiming) {
            require(owner() == msg.sender && deal.status == DealStatus.Delivering, "Error.");
        } else if(_status != DealStatus.Closed) {
            revert("Can't change.");
        }
        
        deal.status = _status;
    }

    function checkDealStatus(
        uint256 _dealId,
        DealStatus _status
    ) public view existDeal(_dealId) returns(bool) {
        DealInfo memory deal = dealInfo[_dealId];
        return deal.status == _status;
    }

    function setDealPrice(
        uint256 _dealId,
        uint256 _price
    ) external existDeal(_dealId) {
        require(!closeAll, "Closed");
        DealInfo storage deal = dealInfo[_dealId];
        require(deal.sponsor == msg.sender, "Must Sponsor.");
        deal.dealPrice.price = _price;
        deal.dealPrice.startDate = block.timestamp;
        deal.status = DealStatus.Offering;

        emit SetDealPrice(_dealId, msg.sender);
    }

    function updateDealPrice(
        uint256 _dealId,
        uint256 _price
    ) external existDeal(_dealId) {
        require(!closeAll, "Closed");
        DealInfo storage deal = dealInfo[_dealId];
        require(deal.sponsor == msg.sender, "Must Sponsor.");
        require(deal.status == DealStatus.Offering, "Wrong Status.");
        deal.dealPrice.updateDate = block.timestamp;
        deal.dealPrice.price = _price;

        emit UpdateDealPrice(_dealId, msg.sender);
    }

    function deposite(
        uint256 _dealId,
        uint256 _amount
    ) external existDeal(_dealId) {
        require(!closeAll, "Closed");
        require(checkDealStatus(_dealId, DealStatus.NotDisplaying) || checkDealStatus(_dealId, DealStatus.Staking) || checkDealStatus(_dealId, DealStatus.Offering), "Wrong Status.");
        require(_amount > 0, "Not Empty.");
        DealInfo storage deal = dealInfo[_dealId];

        if(deal.lead.investor != address(0)) {
            if(deal.lead.investor != msg.sender) {
                require(deal.lead.isStaked, "Can't Stake.");
            } else {
                deal.lead.isStaked = true;
            }
            if(deal.stakeIds.length < 1) {
                deal.status = DealStatus.Staking;
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
        deal.stakeIds.push(stakeId);
        IERC20(deal.stakingToken).transferFrom(staker, address(this), _amount);

        emit Deposit(_dealId, _amount, staker);
    }

    function withdraw(
        uint256 _stakeId
    ) external {
        StakeInfo storage stake = stakeInfo[_stakeId];
        uint256 _dealId = stake.dealId;
        require(stake.staker == msg.sender, "Must Staker");

        if(!closeAll) {
            require(!(checkDealStatus(_dealId, DealStatus.Delivering) && checkDealStatus(_dealId, DealStatus.Claiming)), "Wrong Status.");
        }
        
        DealInfo memory deal = dealInfo[_dealId];
        uint256 _amount = stake.amount;
        stake.amount = 0;
        IERC20(deal.stakingToken).transfer(msg.sender, _amount);

        emit Withdraw(_stakeId, _amount, msg.sender);
    }

    function claim(
        uint256 _dealId
    ) external {
        require(!closeAll, "Closed");
        require(checkDealStatus(_dealId, DealStatus.Claiming), "Wrong Status.");
        DealInfo storage deal = dealInfo[_dealId];
        require(deal.sponsor == msg.sender, "Must Sponsor.");
        deal.status = DealStatus.Closed;
        
        uint256[] memory stakeIds = deal.stakeIds;
        uint256 claimAmount;
        
        for(uint256 i=0; i<stakeIds.length; i++) {
            StakeInfo storage stake = stakeInfo[stakeIds[i]];
            
            if(!stake.isClaimed) {
                claimAmount = claimAmount.add(stake.amount);
                stake.isClaimed = true;

                if(claimAmount > deal.amount.maxSale) {
                    uint256 diffAmount = claimAmount.sub(deal.amount.maxSale);
                    stake.restAmount = diffAmount;
                    stake.amount = stake.amount.sub(diffAmount);
                    claimAmount = deal.amount.maxSale;
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
    ) external {
        StakeInfo storage stake = stakeInfo[_stakeId];
        DealInfo memory deal = dealInfo[stake.dealId];
        require(deal.status == DealStatus.Closed, "Wrong Status.");
        require(deal.sponsor == msg.sender || owner() == msg.sender, "No Permission.");
        uint256 _amount = stake.amount;
        stake.amount = 0;
        IERC20(deal.stakingToken).transfer(stake.staker, _amount);
    }

    function getDealIds(DisplayStatus _displayStatus, DealStatus _dealStatus) external view returns(uint256[] memory) {
        uint256[] memory filterDealIds = new uint256[](dealIds.length);
        uint256 index = 0;
        
        if(_displayStatus == DisplayStatus.All) {
            return dealIds;
        } else {
            for(uint256 id=1; id<=dealIds.length; id++) {
                DealInfo memory deal = dealInfo[id];
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

    function addAllowedToken(address _token) external onlyOwner {
        allowedTokenList[_token] = true;
    }

    function toggleClose() external onlyOwner {
        closeAll = !closeAll;
    }

    function getStakeIds (uint256 _dealId) external view returns(uint256 [] memory) {
        DealInfo memory deal = dealInfo[_dealId];
        return deal.stakeIds;
    }
    
    function getInvetorStakes (address _investor) external view returns(uint256 [] memory) {
        return stakesByInvestor[_investor];
    }
    
    function getSponsorDeals (address _sponsor) external view returns(uint256 [] memory) {
        return dealsBySponsor[_sponsor];
    }
}