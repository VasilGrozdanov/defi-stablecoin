//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
// Has our invariants

import {Test, console2} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {Handler} from "./Handler.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Invariants is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    HelperConfig helperConfig;
    address weth;
    address wbtc;
    Handler handler;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, engine, helperConfig) = deployer.run();
        (,, weth, wbtc,) = helperConfig.activeNetworkConfig();
        handler = new Handler(engine, dsc);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDepopsited = IERC20(weth).balanceOf(address(engine));
        uint256 totalWbtcDepopsited = IERC20(wbtc).balanceOf(address(engine));
        uint256 wethValue = engine.getUsdValue(weth, totalWethDepopsited);
        uint256 wbtcValue = engine.getUsdValue(wbtc, totalWbtcDepopsited);
        console2.log("wethValue: ", wethValue);
        console2.log("wbtcValue: ", wbtcValue);
        console2.log("totalSupply: ", totalSupply);
        console2.log("Times mint is called: ", handler.timesMintIsCalled());

        assert(wethValue + wbtcValue >= totalSupply);
    }

    function invariant_gettersMustNotRevert() public view {
        engine.getCollateralTokens();
        engine.getUsdValue(weth, 0);
        engine.getUsdValue(wbtc, 0);
        engine.getTokenAmountFromUsd(weth, 110 ether);
        engine.getHealthFactor();
    }
}
