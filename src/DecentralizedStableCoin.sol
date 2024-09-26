//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DecentralizedStableCoin
 * @author Vasil Grozdanov
 * Collatteral: Exogenous (wETH & wBTC)
 * Minting: Algorithmic
 * Relative stability: Pegged to USD
 *
 * This is the contract meant to be governed by DSCEngine. This contract is just the ERC20 implementation of our stablecoin system.
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__MustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    constructor() ERC20("Decentralized Stablecoin", "DSC") Ownable() {}

    function burn(uint256 amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        if (amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        } else if (amount > balance) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(amount);
    }

    function mint(address to, uint256 amount) external onlyOwner returns (bool) {
        if (msg.sender == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        } else if (amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }
        _mint(to, amount);
        return true;
    }
}
