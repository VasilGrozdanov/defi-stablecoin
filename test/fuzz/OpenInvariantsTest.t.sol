// //SPDX-License-Identifier: MIT
// pragma solidity ^0.8.18;
// // Has our invariants
// import {Test, console2} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {DeployDSC} from "script/DeployDSC.s.sol";
// import {HelperConfig} from "script/HelperConfig.s.sol";
// import {DSCEngine} from "src/DSCEngine.sol";
// import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract OpenInvariantsTest is Test, StdInvariant {
//     DeployDSC deployer;
//     DSCEngine engine;
//     DecentralizedStableCoin dsc;
//     HelperConfig helperConfig;
//     address weth;
//     address wbtc;

//     function setUp() external {
//         deployer = new DeployDSC();
//         (dsc, engine, helperConfig) = deployer.run();
//         (, , address(weth), address(wbtc), ) = helperConfig
//             .activeNetworkConfig();
//         targetContract(address(dsc));
//     }

//     function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
//         uint256 totalSupply = dsc.totalSupply();
//         uint256 totalWethDepopsited = IERC20(weth).balanceOf(address(engine));
//         uint256 totalWbtcDepopsited = IERC20(wbtc).balanceOf(address(engine));
//         uint256 wethValue = engine.getUsdValue(weth, totalWethDepopsited);
//         uint256 wbtcValue = engine.getUsdValue(wbtc, totalWbtcDepopsited);

//         assert(wethValue + wbtcValue >= totalSupply);
//     }
// }
