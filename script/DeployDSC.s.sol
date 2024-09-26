//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";

contract DeployDSCEngine is Script {
    function run() external returns (DecentralizedStableCoin, DSCEngine) {
        console.log("Deploying DSCEngine...");
        vm.startBroadcast();
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCEngine dscEngine = new DSCEngine(address(dsc));
        vm.stopBroadcast();
        console.log("DSCEngine deployed at: " + address(dscEngine));
        console.log("Decentralized Stable Coin deployed at: " address(dsc));
        return (dsc,dscEngine);
    }
}
