//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

//Narrows down the way we call functioions

contract Handler is Test {
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    ERC20Mock weth;
    ERC20Mock wbtc;
    uint256 public timesMintIsCalled;
    address[] public depositors;
    mapping(address depositor => bool) depositorExists;
    uint256 constant MAX_DEPOSITED_SIZE = type(uint96).max;
    MockV3Aggregator public wethUsdPriceFeed;

    constructor(DSCEngine _engine, DecentralizedStableCoin _dsc) {
        engine = _engine;
        dsc = _dsc;
        address[] memory collateralTokens = engine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
        wethUsdPriceFeed = MockV3Aggregator(
            engine.getCollateralTokenPriceFeed(address(weth))
        );
    }

    modifier depositorsExist() {
        if (depositors.length == 0) {
            return;
        }
        _;
    }

    function depositCollateral(
        uint256 collateralSeed,
        uint256 amountCollateral
    ) public {
        ERC20Mock collateral = ERC20Mock(
            _getCollateralFromSeed(collateralSeed)
        );
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSITED_SIZE);
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(engine), amountCollateral);
        engine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
        if (!depositorExists[msg.sender]) {
            depositorExists[msg.sender] = true;
            depositors.push(msg.sender);
        }
    }

    function mintDsc(
        uint256 addressSeed,
        uint256 amount
    ) public depositorsExist {
        (address user, ) = _getUserFromSeed(addressSeed);

        (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = engine
            .getAccountInformation(user);
        int256 maxDscToMint = int256(totalCollateralValueInUsd / 2) -
            int256(totalDscMinted);
        if (maxDscToMint <= 0) {
            return;
        }
        amount = bound(amount, 1, uint256(maxDscToMint));
        vm.prank(user);
        engine.mintDsc(amount);
        timesMintIsCalled++;
    }

    function redeemCollateral(
        uint256 collateralSeed,
        uint256 amountCollateral
    ) public depositorsExist {
        (address user, uint256 indexOfUser) = _getUserFromSeed(collateralSeed);

        ERC20Mock collateral = ERC20Mock(
            _getCollateralFromSeed(collateralSeed)
        );
        uint256 maxCollateralToRedeem = engine.getMaxRedeemableAmount(
            user,
            address(collateral)
        );
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if (amountCollateral == 0) {
            return;
        }
        vm.prank(user);
        engine.redeemCollateral(address(collateral), amountCollateral);
        if (maxCollateralToRedeem == amountCollateral) {
            _removeDepositor(indexOfUser);
        }
    }

    // This breaks our invariant!!!
    // function updateCollateralPrice(uint96 newPrice) {
    //     int256 price = int256(uint256(newPrice));
    //     wethUsdPriceFeed.updateAnswer(price);
    // }

    function _getCollateralFromSeed(
        uint256 collateralSeed
    ) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }

    function _removeDepositor(uint256 indexOfUser) private {
        depositorExists[depositors[indexOfUser]] = false;
        depositors[indexOfUser] = depositors[depositors.length - 1];
        depositors.pop();
    }

    function _getUserFromSeed(
        uint256 addressSeed
    ) private view returns (address, uint256) {
        uint256 indexOfUser = addressSeed % depositors.length;
        return (depositors[indexOfUser], indexOfUser);
    }
}
