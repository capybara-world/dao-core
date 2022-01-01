// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../governance/Compensation.sol";

// Represents an application of a capybara NFT, for which a proposer /
// implementor and an executor (i.e., a network actor rasterizing a sticker,
// lens, or AR model) can receive compensation.
contract Experience {
	// When the proposal was created
	uint256 public proposalTimestamp;
	// 0 value for the duration of a vote indicates that the rates of
	// compensation are variable for this proposal.
	uint256 public voteDuration;

	address public implementor;
	address public dao;

	// Holders can vote for allocations by allocating their own CPY to the
	// experience contract, voting to use treasury funds, or mint new CPY to
	// compensate implementors and executors.
	// Votes are a weighted average, with weights being users' CPY balances.
	//
	// Contributions and treasury funds are the prioritized compensation
	// mechanism, with minting as a fallback.
	struct CompRate {
		// The total amount from this funding source that can be used
		uint256 balance;

		// The number of CPYs that are used from this balance per compensatable
		// action
		uint256 rate;
	}

	// Holders can set different rates for compensating executors of this
	// experience vs implementors of it.
	mapping internal (COMPENSATION_TYPE => CompRate) implementorCompRates;
	mapping internal (COMPENSATION_TYPE => CompRate) executorCompRates;

	modifier isDao {
		require(msg.sender == this.dao, "only the DAO can pay executors / implementors");
		_;
	}

	modifier isVotable {
		require(
			this.voteDuration == 0 ||
			block.timestamp - this.proposalTimestamp < this.voteDuration days,
			"proposal is no longer voteable"
		);
		_;
	}

	// Metadata for proposals don't need to be viewable by contracts.
	// Proposaly for experiences can be perpetual, or have a due date (duration
	// in days), after which their funding rates will not change.
	event ExperienceProposed(bytes32 detailsIpfsHash, address implementor, uint256 voteDuration);

	// Creates a new proposal for an experience with the given details.
	constructor(bytes32 detailsIpfsHash, address proposer, uint256 duration) {
		this.proposalTimestamp = block.timestamp;
		this.voteDuration = duration;
		this.implementor = proposer;
		this.dao = msg.sender;

		emit ExperienceProposed(detailsIpfsHash, proposer, voteDuration);
	}

	// Places a vote to compensate actors involved in the experience according
	// to the provided rates.
	function voteCompensation(mapping (COMPENSATION_TYPE => uint256) implementorRates, mapping (COMPENSATION_TYPE => uint256) executorRates) isVotable, external {

	}
}
