//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig helperConfig;
    address USER = makeAddr("user");
    address LIQUIDATOR = makeAddr("liquidator");
    uint256 STARTING_BALANCE = 1000 ether;
    uint256 constant SEND_VALUE = 0.1 ether;
    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address weth;
    address wbtc;
    uint256 deployerKey;
    uint256 constant AMOUNT = 15e18;
    address[] tokens;
    address[] priceFeeds;
    uint256 constant PRECISION = 1e18;
    uint256 constant ADDITIONAL_FEED_PRECISION = 1e10;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, engine, helperConfig) = deployer.run();
        (
            wethUsdPriceFeed,
            wbtcUsdPriceFeed,
            weth,
            wbtc,
            deployerKey
        ) = helperConfig.activeNetworkConfig();
    }

    modifier onlyAnvil() {
        if (block.chainid == 31337) {
            _;
        }
    }

    function testRevertsIfTokenLenghtDoesntMatchPriceFeeds() external {
        tokens.push(weth);
        priceFeeds.push(wethUsdPriceFeed);
        priceFeeds.push(wbtcUsdPriceFeed);
        vm.expectRevert(
            DSCEngine
                .DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLenght
                .selector
        );
        new DSCEngine(tokens, priceFeeds, address(dsc));
    }

    function testGetUsdValue() external view onlyAnvil {
        uint256 price = uint256(helperConfig.ETH_USD_PRICE()) /
            (10 ** helperConfig.DECIMALS());
        uint256 actualPrice = engine.getUsdValue(weth, AMOUNT);
        console.log(price);
        console.log(actualPrice);
        assert(actualPrice == AMOUNT * price);
    }

    function testGetTokenAmountFromUsd() external view onlyAnvil {
        uint256 expectedWethInWei = (AMOUNT /
            uint256(helperConfig.ETH_USD_PRICE())) *
            (10 ** helperConfig.DECIMALS());
        uint256 actualAmountInWei = engine.getTokenAmountFromUsd(weth, AMOUNT);
        console.log(expectedWethInWei);
        console.log(actualAmountInWei);
        assert(actualAmountInWei == expectedWethInWei);
    }

    modifier mintedAndApproved(
        address tokenAddress,
        address _to,
        uint256 _amount
    ) {
        ERC20Mock token = ERC20Mock(tokenAddress);
        token.mint(_to, AMOUNT);
        token.approveInternal(_to, address(engine), _amount);
        _;
    }

    function testDepositCollateralOk()
        public
        mintedAndApproved(weth, USER, AMOUNT)
        onlyAnvil
    {
        vm.recordLogs();
        vm.prank(USER);
        engine.depositCollateral(weth, AMOUNT);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        (uint256 actualTotalDscMinted, uint256 actualCollateralValue) = engine
            .getAccountInformation(USER);
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedCollateralValue = engine.getUsdValue(weth, AMOUNT);
        assert(entries[0].topics[1] == bytes32(uint256(uint160(USER))));
        assert(entries[0].topics[2] == bytes32(uint256(uint160(weth))));
        assert(entries[0].topics[3] == bytes32(uint256(AMOUNT)));
        assert(engine.getCollateralAmountDeposited(USER, weth) == AMOUNT);
        assert(expectedTotalDscMinted == actualTotalDscMinted);
        assert(expectedCollateralValue == actualCollateralValue);
    }

    function testDepositCollateralRevertsOnTokenNotAllowed() external {
        ERC20Mock token = new ERC20Mock("Test", "TST", USER, AMOUNT);

        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        engine.depositCollateral(address(token), AMOUNT);
    }

    function testDepositCollateralRevertsZeroTransfer()
        external
        mintedAndApproved(weth, USER, AMOUNT)
    {
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        vm.prank(USER);
        engine.depositCollateral(weth, 0);
    }

    function testMintDscOk() external onlyAnvil {
        testDepositCollateralOk();
        uint256 amount = engine.getAccountCollateralValue(USER);
        vm.prank(USER);
        engine.mintDsc(amount / 2);
    }

    function testMintDscRevert() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__BreaksHealthFactor.selector,
                0
            )
        );
        engine.mintDsc(1);
    }

    modifier depositedAndMinted(
        address tokenAddress,
        address _to,
        uint256 _amountCollateral,
        uint256 _amountDsc
    ) {
        ERC20Mock token = ERC20Mock(tokenAddress);
        token.mint(_to, _amountCollateral);
        token.approveInternal(_to, address(engine), _amountCollateral);
        vm.prank(_to);
        engine.depositCollateralAndMintDsc(
            tokenAddress,
            _amountCollateral,
            _amountDsc
        );
        _;
    }

    function testDepositAndMintDscOk()
        public
        mintedAndApproved(weth, USER, AMOUNT)
    {
        vm.prank(USER);
        engine.depositCollateralAndMintDsc(weth, AMOUNT, AMOUNT);
        (uint256 actualTotalDscMinted, ) = engine.getAccountInformation(USER);
        uint256 ethPrice = uint256(helperConfig.ETH_USD_PRICE());

        assertEq(actualTotalDscMinted, AMOUNT);
        assertEq(engine.getCollateralAmountOfUser(USER, weth), AMOUNT);
    }

    function testRedeemCollateralRevertsIfHealthFactorIsBroken()
        external
        depositedAndMinted(weth, USER, AMOUNT, AMOUNT)
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__BreaksHealthFactor.selector,
                0
            )
        );
        vm.prank(USER);
        engine.redeemCollateral(weth, AMOUNT);
    }

    function testRedeemCollateralOk()
        external
        depositedAndMinted(weth, USER, AMOUNT, AMOUNT)
    {
        uint256 amountToRedeem = engine.getMaxRedeemableAmount(USER, weth);
        vm.recordLogs();
        vm.prank(USER);
        engine.redeemCollateral(weth, amountToRedeem);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries[0].topics[1], bytes32(uint256(uint160(USER))));
        assertEq(entries[0].topics[2], bytes32(uint256(uint160(USER))));
        assertEq(entries[0].topics[3], bytes32(uint256(uint160(weth))));
        assertEq(abi.decode(entries[0].data, (uint256)), amountToRedeem);
        assertEq(
            engine.getCollateralAmountOfUser(USER, weth),
            AMOUNT - amountToRedeem
        );
    }

    function testBurnDscOk()
        external
        depositedAndMinted(weth, USER, AMOUNT, AMOUNT)
    {
        (uint256 totalDscMinted, ) = engine.getAccountInformation(USER);

        vm.startPrank(USER);
        dsc.approve(address(engine), totalDscMinted);
        engine.burnDsc(totalDscMinted);
        vm.stopPrank();

        assertEq(dsc.balanceOf(USER), 0);
    }

    function testLiquidateRevertsIfHealthFactorIsOk() external {
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        engine.liquidate(weth, USER, AMOUNT);
    }

    function testLiquidateOk()
        external
        onlyAnvil
        depositedAndMinted(weth, USER, 1 ether, (1 ether / 2) * 2500)
        depositedAndMinted(weth, LIQUIDATOR, AMOUNT * 10, 1 ether * 2500)
    {
        uint256 userStartingCollateral = engine.getCollateralAmountDeposited(
            USER,
            weth
        );
        uint256 liquidatorStartingCollateral = engine
            .getCollateralAmountDeposited(LIQUIDATOR, weth);
        MockV3Aggregator priceFeed = MockV3Aggregator(
            engine.getCollateralTokenPriceFeed(weth)
        );
        (, int256 currentPrice, , , ) = priceFeed.latestRoundData();
        int256 newPrice = currentPrice - 1;
        priceFeed.updateAnswer(newPrice);
        (uint256 totalDscMinted, ) = engine.getAccountInformation(USER);

        vm.startPrank(LIQUIDATOR);
        dsc.approve(address(engine), totalDscMinted);
        engine.liquidate(weth, USER, totalDscMinted);
        vm.stopPrank();

        assertLe(
            engine.getCollateralAmountOfUser(USER, weth),
            userStartingCollateral
        );
        assertLe(
            liquidatorStartingCollateral,
            engine.getCollateralAmountOfUser(LIQUIDATOR, weth)
        );
    }
}
