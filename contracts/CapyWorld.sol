// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./CapyCredits.sol";
import "./governance/Compensation.sol";

contract CapyWorld {
	// Total supply of capy credits, which are allocated in blocks of 10%
	uint256 internal constant INITIAL_SUPPLY 	= 10_000_000;
	uint8 	internal constant SUPPLY_SLOTS 		= 10;

	/* Allocation of Capy Credits:
	 * - 50%: fundraised to private individuals
	 * - 30%: locked in the CapyWorld DAO for funding community proposals
	 * - 20%: dev fund
	 */
	uint8 internal constant SALE_SLOTS		= 5;
	uint8 internal constant LOCKED_SLOTS	= 3;
	uint8 internal constant FUND_SLOTS		= 2;

	// The initial crowdsale will last 14 days
	uint8 	internal constant 	N_SALE_DAYS = 14;
	uint256 internal immutable 	SALE_START_DATE;

	// Minimum threshold (30%) of coins sold to allow the crowdsale to be
	// completed. If this percentage of the 50% to be sold is not hit,
	// ETH transfers are reverted, and no coins are minted. If the percentage
	// is above the threshold, the given % of coins are minted and transferred
	// to the respective holders, with the remaining coins locked in the DAO.
	uint8 internal constant MIN_SLOTS_SOLD = 3;

	// The fixed price in WEIs of each capybara credit sold in the crowdsale
	uint256 internal constant SALE_EXCHANGE_RATE = 1_000_000_000_000_000;

	// Number of tokens that will be allocated, and have received funds for
	uint256 public tokensSold;

	// Tracks which users have placed orders, how many tokens they've
	// ordered, and their index in the holders list
	mapping (address => (uint256, uint256)) public orders;
	address[] internal holders;

	/* When a user wishes to render a sticker, AR lens, or video lens, the
	 * compensation levels for rendering / rasterizing these experiences are
	 * stored in a corresponding smart contract. Experiences can be proposed by
	 * artists, and holders of CPY can vote on how much to compensate the user
	 * by.
	 */
	address[] public proposedExperiences;
	address[] public experiences;

	address 	internal devFund;
	CapyCredits internal coin;

	// Indicates that a user successfully placed an order for the given number
	// of tokens and the indicated WEI refund amount (i.e., in case the amount
	// was not easily divisible).
	event OrderPlaced(address holder, uint256 tokensOrdered, uint256 weiRefunded);

	// A user successfully canceled their token order, with the indicated
	// amount of tokens released and the given refund sent.
	event OrderCanceled(address holder, uint256 tokensCanceled, uint256 weiRefunded);

	// Indicates that a user's order was fulfilled, and that the sale met the
	// threshold.
	event OrderFilled(address holder, uint256 tokensAllocated);

	// Indicates that a user's order was canceled, since the threshold wasn't met.
	event OrderReverted(address holder, uint256 tokensCanceled, uint256 weiRefunded);

	// Users cannot purchase new coins through the crowdsale after it has
	// completed
	modifier saleOngoing {
		require(this.saleActive(), "token sale is already over");
		_;
	}

	// A review by a user for an experience rendered by a network participant.
	// When signed, a review allows a network participant to claim a bonus of
	// the amount stored in the DAO's compensation mapping.
	struct Review {
		// The time at which the review was made
		uint256 time;
	}

	// The DAO allocates the above percentage to its developer fund,
	// and reserve the right to mint the remaining after its initial coin
	// offering is completed.
	constructor() {
		// This contract is the creator of the capybara credit contract, and
		// thus has the exclusive ability to mint new credits
		this.coin = new CapyCredits();

		// Dev fund
		this.coin.mint(msg.sender, INITIAL_SUPPLY / SUPPLY_SLOTS * FUND_SLOTS * this.coin.decimals());

		// Start the crowdsale for the coin
		this.SALE_START_DATE = block.timestamp;
	}

	// Returns false if the end date of the sale has passed.
	function saleActive() public returns (bool) {
		return block.timestamp - SALE_START_DATE < N_SALE_DAYS days;
	}

	// Returns the number of tokens the given wei can buy, and the
	// remainder in weis.
	function weiToTokenDecimals(uint256 weis) returns (uint256, uint256) {
		return weis / SALE_EXCHANGE_RATE * this.coin.decimals(), weis % SALE_EXCHANGE_RATE;
	}

	// Returns the number of weis the given number of tokens
	// (decimals included) is worth, regardless of remainder (handled before
	// any tokens ordered).
	function tokenDecimalsToWei(uint256 decimalTokens) returns uint256 {
		return decimalTokens / this.coin.decimals() * SALE_EXCHANGE_RATE;
	}

	// Allows a user to purchase capybara credits according to the above
	// exchange rate while the token sale is active.
	function placeOrder() external payable saleOngoing {
		// The number of tokens to allocate to the user
		(uint256 tokensPurchased, uint256 purchaseRemainder) = weiToTokenDecimals(msg.value);

		// The user cannot send an amount that would give them more credits
		// than will be sold
		require(this.tokensSold + tokensPurchased <= INITIAL_SUPPLY / SUPPLY_SLOTS * SALE_SLOTS * this.coin.decimals());

		if (purchaseRemainder > 0)
			require(msg.sender.call.value(purchaseRemainder), "could not refund order remainder")
		
		// Register the order
		uint256 holderIdx = this.holders.push(msg.sender);
		this.orders[msg.sender] = (holderIdx, tokensPurchased);

		this.tokensSold += tokensPurchased;

		emit OrderPlaced(msg.sender, tokensPurchased, purchaseRemainder);
	}

	// Allows a user to cancel their oder, if they have one.
	// Refund the appropriate number of wei.
	function cancelOrder() external saleOngoing {
		(uint256 holderIdx, uint256 amtOrdered) = this.orders[msg.sender];

		require(amtOrdered > 0, "no tokens ordered");

		// Refund the user's order
		uint256 weiToRefund = this.tokenDecimalsToWei(amtOrdered);
		require(msg.sender.call.value(weiToRefund), "could not refund order");

		// Clear user orders
		delete this.orders[msg.sender];

		this.holders[holderIdx] = this.holders[this.holders.length - 1];
		this.holders.pop();

		this.tokensSold -= amtOrdered;

		emit OrderCanceled(msg.sender, amtOrdered, weiToRefund);
	}

	// Once the sale has passed its expiry date, this releases funds to the
	// users that placed orders, if the threshold was not met. Otherwise, the
	// tokens are issued to the appropriate addresses.
	function endSale() external {
		require(!this.saleActive(), "sale is still ongoing");

		// Not enough tokens were sold. Restart the sale.
		bool restartSale = this.tokensSold < INITIAL_SUPPLY / SUPPLY_SLOTS * SALE_SLOTS / SUPPLY_SLOTS * MIN_SLOTS_SOLD * this.coin.decimals();

		// The same process is used for refunding orders as fulfilling them
		for (uint i = 0; i < this.holders.length; i++) {
			address storage holder = this.holders[i];
			(uint256 holderIdx, uint256 amtOrdered) = this.orders[holder];

			if (restartSale) {
				// Refund their contribution
				uint256 toRefund = tokenDecimalsToWei(amtOrdered);
				holder.call.value(toRefund);
				this.tokensSold -= amtOrdered;

				emit OrderReverted(holder, amtOrdered, toRefund);
			} else {
				// Allocate the holder's tokens
				this.coin.mint(holder, amtOrdered);

				emit OrderFilled(holder, amtOrdered);
			}
		}

		// Send any eth left over to the dev fund
		this.devFund.call.value(address(this).balance);

		// Records for orders are no longer needed
		delete this.orders;
		delete this.holders;
	}
}
