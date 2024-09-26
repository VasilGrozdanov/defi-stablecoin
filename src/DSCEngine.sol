//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "src/libraries/OracleLib.sol";

/**
 * @title DSCEngine
 * @author Vasil Grozdanov
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == 1$ peg.
 * This stablecoin has the properties:
 * - Exogenous collateral
 * - Dollar pegged
 * - Algorithmically stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was only backed by WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of all the collateral <= the $ backed value of of all the DSC.
 *
 * @notice This contract is core of the DSC system. It handles all the logic for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is VERY loosely based on the MakerDAO DSS (DAI) system.
 */
contract DSCEngine is ReentrancyGuard {
    /////////////////////
    ////    errors   ////
    /////////////////////
    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLenght();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 userHealthFactor);
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();
    /////////////////////
    ////    types    ////
    /////////////////////

    using OracleLib for AggregatorV3Interface;

    /////////////////////
    ////  state vars ////
    /////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 public constant PERCENTAGE_PRECISION = 100;
    uint256 public constant LIQUIDATION_BONUS = 10;
    uint256 private constant MIN_HEALTH_FACTOR = 1;
    uint256 private constant LIQUIDATION_TRESHOLD = 50;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount))
        private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;
    DecentralizedStableCoin private immutable i_dsc;

    /////////////////////
    ////    events   ////
    /////////////////////
    event CollateralDeposited(
        address indexed from,
        address indexed token,
        uint256 indexed amount
    );
    event CollateralRedeemed(
        address indexed from,
        address indexed to,
        address indexed token,
        uint256 amount
    );

    /////////////////////
    ////  modifiers  ////
    /////////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__TokenNotAllowed();
        }
        _;
    }

    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address dscAddress
    ) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLenght();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    ///////////////////////////////
    ////  external functions  /////
    ///////////////////////////////

    /**
     *
     * @param tokenCollateralAddress the address of the token to deposit as collateral
     * @param amountCollateral the amount of collateral to deposit
     * @param amountDscToMint the amount of decentralized stable coin to mint
     * @notice this function will deposit collateral and mint DSC in one transaction
     */
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /**
     * @notice follows CEI
     * @param tokenCollateralAddress the address of the token to deposit as collateral
     * @param amount the amount of collateral to deposit
     */
    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amount
    )
        public
        moreThanZero(amount)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amount;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amount);

        bool success = IERC20(tokenCollateralAddress).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     *
     * @param tokenCollateralAddress the address of the token collateral to redeem
     * @param amountCollateral the amount of collateral to redeem
     * @param amountDscToBurn the amount of decentralized stable coin to burn
     * @notice this function will redeem collateral and burn DSC in one transaction
     */
    function redeemCollateralForDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToBurn
    ) external {
        burnDsc(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
    }

    function redeemCollateral(
        address tokenCollateralAddress,
        uint256 amount
    ) public moreThanZero(amount) nonReentrant {
        _redeemCollateral(
            msg.sender,
            msg.sender,
            tokenCollateralAddress,
            amount
        );
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice follows CEI
     * @param amountDscToMint the amount of decentralized stable coin to mint
     * @notice they must have more collateral value than the minimum treshold
     */
    function mintDsc(
        uint256 amountDscToMint
    ) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool isMinted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!isMinted) {
            revert DSCEngine__TransferFailed();
        }
    }

    function burnDsc(uint256 amount) public moreThanZero(amount) nonReentrant {
        _burnDsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     *
     * @param collateral the erc20 collateral address to liquidate
     * @param user the address of the user that broken the health factor. Their health factor must be below MIN_HEALTH_FACTOR
     * @param debtToCover the amount of DSC you want to burn to improve user's health factor
     * @notice you can partially or fully liquidate a user
     * @notice you will get a liquidation bonus for taking the user's funds
     * @notice this function working assumes the protocol will be roughly 200% overcollateralized in order for this to work
     * @notice a known bug would be if the system is 100% or less collateralized, then we wouldn't be able to insenticise the liquidators
     */
    function liquidate(
        address collateral,
        address user,
        uint256 debtToCover
    ) external moreThanZero(debtToCover) nonReentrant {
        uint256 startingHealthFactor = _healthFactor(user);
        if (startingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(
            collateral,
            debtToCover
        );
        uint256 bonusCollateral = (tokenAmountFromDebtCovered *
            LIQUIDATION_BONUS) / PERCENTAGE_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered +
            bonusCollateral;

        _redeemCollateral(
            user,
            msg.sender,
            collateral,
            totalCollateralToRedeem
        );

        _burnDsc(debtToCover, user, msg.sender);
        uint256 endingHealthFactor = _healthFactor(user);
        if (endingHealthFactor <= startingHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    //////////////////////////////////////////
    ////  private and internal functions  ////
    //////////////////////////////////////////

    /**
     * @dev low level internal function. Do not call, unless the caller fuinction is checking if the health factor is broken
     */
    function _burnDsc(
        uint256 amountDscToBurn,
        address onBehalfOf,
        address dscFrom
    ) private {
        s_DSCMinted[onBehalfOf] -= amountDscToBurn;
        bool isBurned = i_dsc.transferFrom(
            dscFrom,
            address(this),
            amountDscToBurn
        );
        if (!isBurned) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDscToBurn);
    }

    function _redeemCollateral(
        address from,
        address to,
        address tokenCollateralAddress,
        uint256 amount
    ) private {
        s_collateralDeposited[from][tokenCollateralAddress] -= amount;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amount);

        bool success = IERC20(tokenCollateralAddress).transfer(to, amount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _getAccountInformation(
        address user
    ) private view returns (uint256 totalDscMinted, uint256 totalCollateral) {
        totalDscMinted = s_DSCMinted[user];
        totalCollateral = getAccountCollateralValue(user);
        return (totalDscMinted, totalCollateral);
    }

    /**
     * Returns how close to liquidation a user is.
     * If a user goes below 1, it means he can be liquidated.
     * @param user the address of the user
     */
    function _healthFactor(address user) internal view returns (uint256) {
        (
            uint256 totalDscMinted,
            uint256 collateralValueInUsd
        ) = _getAccountInformation(user);
        if (totalDscMinted == 0) {
            return type(uint256).max;
        }
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd *
            LIQUIDATION_TRESHOLD) / PERCENTAGE_PRECISION;

        return (collateralAdjustedForThreshold) / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    /////////////////////////////////////////
    ////    public and view functions    ////
    /////////////////////////////////////////

    /**
     * Returns the amount of tokens equivalent to their USD value, according to the price feed
     * @param token the address of the token
     * @param usdAmountInWei the amount of USD in wei (18 decimals). For example, 100e18 = 100 USD
     */
    function getTokenAmountFromUsd(
        address token,
        uint256 usdAmountInWei
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[token]
        );
        (, int256 price, , , ) = priceFeed.stalePriceCheck();
        return
            (usdAmountInWei * PRECISION) /
            (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getCollateralAmountDeposited(
        address user,
        address token
    ) public view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getAccountCollateralValue(
        address user
    ) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }

        return totalCollateralValueInUsd;
    }

    /**
     * Returns the USD value of an amount of tokens, according to the price feed
     * @param token the address of the token
     * @param amount the amount of tokens
     * @notice The price is in Wei. For example 100e18 = 100 USD
     */
    function getUsdValue(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[token]
        );
        (, int256 price, , , ) = priceFeed.stalePriceCheck();

        // ETH/USD and BTC/USD have the same number of decimals. Replace ADDITIONAL_FEED_PRECISION constant with a function if needed
        return
            ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function getAccountInformation(
        address user
    ) external view returns (uint256 totalDscMinted, uint256 totalCollateral) {
        return _getAccountInformation(user);
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getHealthFactor() external view returns (uint256) {
        return _healthFactor(msg.sender);
    }

    function getCollateralAmountOfUser(
        address user,
        address token
    ) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getMaxRedeemableAmount(
        address user,
        address token
    ) external view returns (uint256) {
        if (_healthFactor(user) < MIN_HEALTH_FACTOR) {
            return 0;
        }

        (
            uint256 totalDscMinted,
            uint256 totalCollateralValueInUsd
        ) = _getAccountInformation(user);
        uint256 maxUsdRedeemable = totalCollateralValueInUsd -
            (totalDscMinted * 2);
        uint256 maxRedeemableTokenAmount = getTokenAmountFromUsd(
            token,
            maxUsdRedeemable
        );
        uint256 maxCollateralDeposited = getCollateralAmountDeposited(
            user,
            token
        );
        return
            maxRedeemableTokenAmount > maxCollateralDeposited
                ? maxCollateralDeposited
                : maxRedeemableTokenAmount;
    }

    function getCollateralTokenPriceFeed(
        address token
    ) external view returns (address) {
        return s_priceFeeds[token];
    }
}
