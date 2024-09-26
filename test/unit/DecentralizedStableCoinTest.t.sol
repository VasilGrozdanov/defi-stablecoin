//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {Vm} from "forge-std/Vm.sol";

contract DecentralizedStableCoinTest is Test {
    DecentralizedStableCoin dsc;
    uint256 constant SEND_VALUE = 0.1 ether;
    address owner;

    function setUp() external {
        dsc = new DecentralizedStableCoin();
        owner = address(this);
    }

    modifier minted() {
        vm.prank(owner);
        dsc.mint(owner, SEND_VALUE);
        _;
    }

    function testInitialization() external {
        assertEq(dsc.totalSupply(), 0);
        assertEq(dsc.decimals(), 18);
        assertEq(dsc.name(), "Decentralized Stablecoin");
        assertEq(dsc.symbol(), "DSC");
    }

    function testMintOk() external {
        vm.prank(owner);
        bool isMinted = dsc.mint(owner, SEND_VALUE);
        assertEq(isMinted, true);
        assertEq(dsc.totalSupply(), SEND_VALUE);
    }

    function testBurnOk() external minted {
        vm.prank(owner);
        dsc.burn(SEND_VALUE);

        assertEq(dsc.totalSupply(), 0);
        assertEq(dsc.balanceOf(owner), 0);
    }

    function testBurnRevertsOnZeroAmount() external minted {
        vm.prank(owner);
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustBeMoreThanZero.selector);
        dsc.burn(0);
    }

    function testBurnRevertsOnAmountMoreThanBalance() external minted {
        vm.prank(owner);
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__BurnAmountExceedsBalance.selector);
        dsc.burn(SEND_VALUE + 1);
    }
}
