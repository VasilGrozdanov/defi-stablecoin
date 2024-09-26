//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployDSC is Script {
    address[] public tokens;
    address[] public priceFeeds;

    function run()
        external
        returns (DecentralizedStableCoin, DSCEngine, HelperConfig)
    {
        console.log("Deploying DSCEngine...");
        HelperConfig helperConfig = new HelperConfig();
        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address weth,
            address wbtc,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        tokens = [weth, wbtc];
        priceFeeds = [wethUsdPriceFeed, wbtcUsdPriceFeed];
        vm.startBroadcast();
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCEngine dscEngine = new DSCEngine(tokens, priceFeeds, address(dsc));
        dsc.transferOwnership(address(dscEngine));
        vm.stopBroadcast();
        console.log("DSCEngine deployed at: ", address(dscEngine));
        console.log("Decentralized Stable Coin deployed at: ", address(dsc));
        return (dsc, dscEngine, helperConfig);
    }
}
