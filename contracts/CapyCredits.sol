// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CapyCredits is ERC20 {
	// Only the DAO creating the coin can mint new coins
	address public dao;

	modifier isDao {
		require(msg.sender == this.dao, "only the DAO can issue new credits");
		_;
	}

	constructor() ERC20("Capy Credits", "CPY") {
		this.dao = msg.sender;
	}

	// Allows the DAO to mint new coins.
	// This is the only allowed method for minting credits.
	function mint(address to, uint256 amount) external isDao {
		_mint(to, amount);
	}

	// Allows the DAO to update itself.
	function updateDao(address dao) external isDao {
		this.dao = dao;
	}
}
