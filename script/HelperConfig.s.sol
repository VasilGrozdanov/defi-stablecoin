//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }
    NetworkConfig public activeNetworkConfig;
    uint8 constant DECIMALS = 8;
    int256 constant INITIAL_ETH_PRICE = 2500e8;
    int256 constant INITIAL_BTC_PRICE = 63000e8;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaConfig() internal pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
                wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
                weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
                wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
                deployerKey: vm.envUint("SEPOLIA_PRIVATE_KEY")
            });
    }

    function getOrCreateAnvilConfig() internal returns (NetworkConfig memory) {
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        MockV3Aggregator mockEthPriceFeed = new MockV3Aggregator(
            DECIMALS,
            INITIAL_ETH_PRICE
        );
        MockV3Aggregator mockBtcPriceFeed = new MockV3Aggregator(
            DECIMALS,
            INITIAL_BTC_PRICE
        );
        ERC20Mock weth = new ERC20Mock(
            "Wrapped Ether",
            "WETH",
            18,
            address(mockEthPriceFeed)
        );
        ERC20Mock wbtc = new ERC20Mock(
            "Wrapped Bitcoin",
            "WBTC",
            18,
            address(mockBtcPriceFeed)
        );
        vm.stopBroadcast();
        return
            NetworkConfig(address(mockEthPriceFeed), address(mockBtcPriceFeed));
    }
}
