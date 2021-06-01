- deploy contract script
Needs to change from old launchpool deploy script to new launchpooltracker based deploy script
	Current script uses old launchpool contract deployment script and now we need to change the deploy logic with launchpooltracker contract
Needs to define allowance logic with approve in deploy script
	Needs to make sure allwance logic for all members in the team and also define where approve logic should be put correctly
StakeVault contract deploy addres is fixed with SPONSOR_ADDRESS?
	Current deploy script deploy the StakeVault contract with SPONSOR_ADDRESS as a fixed address and I think this is not good idea.

- LunchPoolTracker Contract
Needs to add return poolId array function
	At this moment, we can only get one launchpoolid so I suggest to add a function which returns the poolIds array.
Needs to add investor address into Stake struct
	At this moment, there is not investor address in Stake struct and use StakeByAccount map, but if we add investor address into Stake struct, we can save memory size by removing StakeByAccount map...
Needs to add more detailed stages into Stages enum
	We need to define the pool stages in detail and add more stages into Stages enum
Needs to add delete pool function (in the case of mistake)
	If sponsor add a pool with incorrect info as a mistake, we need to delete this pool from pool list
Needs to change Staked, UnStaked event
	At this moment Staked and UnStaked have their own list together and it wastes a lot of memory so I suggest to use Staked list only and if user unstake, change flag or amount of stake in Staked list with the index
Needs to add poolDetail into launchpool struct
	At this moment, there is not any detailed info in launchpool contract...
Some functions and modifiers in this contract have not comment
	functions: _atStage(), _findStake(), _removeStakeFromAccount(), stakesOf(), poolStakeCount(), _isAfterOfferClose, canRedeemOffer()
	modifiers: isTokenAllowed(), isPoolOpen(), canStake(), canCommit(), senderOwnsStake(), isOfferOpen()
Some variable names and function names need to change
	canRedeemOffer() -> canClaimOffer(), redeemOffer() -> claimOffer()
	payeee -> investor, _placeInLine (This is not meaningful)
	Change comment of stakeCount (total amount of Stakes -> count of Stakes)
	Add totalStakeAmount, commitCount variable in LaunchPool Struct

- StakeVault Contract
Found some error
	StakeVault.sol line:100
		assert(_poolDeposits[poolId]._depositsByAccount[payee] <= totalDeposited);
	totalDeposited -> _poolDeposits[poolId].totalDeposited
Needs to change withdrawAddress from public to private
	I think withdrawAddress should be private based because of the security part
Some functions and modifiers in this contract have not comment
	functions: depositsOf(), depositsOfByToken(), depositsOfPool(), _removeAmount()
	modifiers: calledByPool()
Some variable names and function names need to change
	payeee -> investor

