//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DecentralizedStableCoin} from "./DecentralizedStablecoin.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/*
* @title DSC Engine
* @author Abhivansh
* @notice This contract is the core of the Decentralized Stablecoin (DSC) protocol. It ensures that the stablecoin will work like DAI (without governance, without fees and backed by WETH and WBTC) which will pegged to 1 USD. The system would be overcollaterized.
*/
contract DSCEngine is ReentrancyGuard { 
    DecentralizedStableCoin public dsc;

    error DSC_TokenAddressAndPriceFeedAddressArrayMustBeSameLength();
    error DSC_TokenNotSupported();
    error DSC_AmountLessThanZero();
    error DSC_TransferFailed();
    error DSC_HealthFactorBelowThreshold();
    error DSC_TokenAddressCantBeZero();
    error DSC_HealthFactorAboveThresholdAndNeedNotToBeLiquidated();
    error DSC_HealthFactorNotImproved();

    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_BONUS = 10;

    mapping(address token => address priceFeed) public tokenPriceFeedMapping;
    mapping(address user => mapping(address token => uint256 amount)) public userCollateralBalanceWithToken;
    mapping(address user => uint256 tokens) private userDSCBalance;
    address[] private collateralTokens;

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralRedeemed(address indexed from, address indexed to, address indexed token, uint256 amount);

    modifier UnsupportedToken(address tokenAddress) {
        if (tokenPriceFeedMapping[tokenAddress] == address(0)) {
            revert DSC_TokenNotSupported();
        }
        _;
    }

    modifier AmountLessThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSC_AmountLessThanZero();
        }
        _;
    }

    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address dscAddress 
    ) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSC_TokenAddressAndPriceFeedAddressArrayMustBeSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            if (tokenAddresses[i] == address(0)) {
                revert DSC_TokenAddressCantBeZero();
            }
            tokenPriceFeedMapping[tokenAddresses[i]] = priceFeedAddresses[i];
            collateralTokens.push(tokenAddresses[i]);
        }

        dsc = DecentralizedStableCoin(dscAddress);
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountinWei) public view UnsupportedToken AmountLessThanZero returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(tokenPriceFeedMapping[token]);
        (, int256 price, , ,) = priceFeed.latestRoundData();
        return (usdAmountinWei * (10**18))/((uint256(price))*(10**10));
    }

    /*
    * @notice This functions allows the liquidation of the unpaid debt.
    * @notice This function is called by the person who is willing the cover the debt.
    * @notice The person gets some bonus too for covering this.
    * @notice The contract will only be able to give incentives for collaterization if the protocol is overcollaterized.
    */
    function liquidate (address tokenCollaterizationAddress, address userWhoDefaulted, uint256 debtToBeCovered) public AmountLessThanZero(debtToBeCovered) UnsupportedToken(tokenCollaterizationAddress) nonReentrant {
        if (!checkingIfHealthFactorIsBelowThreshold(user)) {
            revert DSC_HealthFactorAboveThresholdAndNeedNotToBeLiquidated();
        }
        uint256 startingUserHealthFactor = calcualtingHealthFactor(userWhoDefaulted);
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(tokenCollaterizationAddress, debtToBeCovered);
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS)/100;
        uint256 totalCollateral = tokenAmountFromDebtCovered + bonusCollateral;
        _i_redeemCollateral(tokenCollaterizationAddress, user, msg.sender, debtToBeCovered);
        _i_burnDsc(debtToBeCovered, userWhoDefaulted, msg.sender);

        uint256 endingUserHealthFactor = calcualtingHealthFactor(userWhoDefaulted);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSC_HealthFactorNotImproved();
        }
    }

    /*
    * @notice This function is used to burn DSC and redeem collateral from the contract
    */
    function burnDscAndRedeemCollateral (address tokenCollateralAddress, uint256 amountToRedeem, uint256 dscToBurn) public {
        burnDsc(dscToBurn);
        redeemCollateral(tokenCollateralAddress, amountToRedeem);
    }

    /*
    * @notice This functions burns the DSC from the contract.
    */
    function burnDsc (uint256 amount) public AmountLessThanZero(amount) {
        _burnDscInternal(amount, msg.sender);
        // i guess it will not be required!!
        if (!checkingIfHealthFactorIsBelowThreshold(msg.sender)) {
            revert DSC_HealthFactorBelowThreshold();
        }
    }

    function _i_burnDsc (uint256 amount, address defaultUser, address dscFrom) private AmountLessThanZero(amount) {
        userDSCBalance[user] -= amount;
        bool success = dsc.transferFrom(dscFrom, address(this), amount);
        if (!success) {
            revert DSC_TransferFailed();
        }
        dsc.burn(amount);
    }

    /*
    * @notice This function redeems the collateral from the contract
    */
    function redeemCollateral (address tokenCollateralAddress, uint256 collateralAmount) public nonReentrant AmountLessThanZero(collateralAmount) UnsupportedToken(tokenCollateralAddress) {
        _redeemCollateralInternal(tokenCollateralAddress, msg.sender, msg.sender, collateralAmount);
        if (!checkingIfHealthFactorIsBelowThreshold(msg.sender)) {
            revert DSC_HealthFactorBelowThreshold();
        }
    }

    function _i_redeemCollateralInternal (address token, address from, address to, uint256 amount) private AmountLessThanZero(amount) UnsupportedToken(token) {
        userCollateralBalanceWithToken[fromr][tokenCollateralAddress] -= collateralAmount;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, collateralAmount);
        bool success = IERC20(tokenCollateralAddress).transfer(to, collateralAmount);
        if (!success) {
            revert DSC_TransferFailed();
        }
    }

    /*
    * @notice This function allows users to deposit collateral tokens and mint DSC into and from the system respectively.
    */
    function depositCollateralAndMintDsc (address tokenCollateralAddress, uint256 collateralAmount, uint256 amountDscToMint) external {
        depositCollateral(tokenCollateralAddress, collateralAmount);
        mintDsc(amountDscToMint);
    }

    /*
    * @notice This function allows users to deposit collateral tokens into the system.
    */
    function depositCollateral(address collateralTokenAddress, uint256 collateralAmount) public nonReentrant AmountLessThanZero(collateralAmount) UnsupportedToken(collateralTokenAddress) {
        userCollateralBalanceWithToken[msg.sender][collateralTokenAddress] += collateralAmount;
        emit CollateralDeposited(msg.sender, collateralTokenAddress, collateralAmount);
        bool successfulTransaction = IERC20(collateralTokenAddress).transferFrom(msg.sender, address(this), collateralAmount);
        if (!successfulTransaction) {
            revert DSC_TransferFailed();
        }
    }

    /*
    * @notice This function mints DSC from the system.
    */
    function mintDsc (uint256 _DscAmount) public nonReentrant AmountLessThanZero(_DscAmount) {
        userDSCBalance[msg.sender] += _DscAmount;
        if (!checkingIfHealthFactorIsBelowThreshold(msg.sender)) {
            revert DSC_HealthFactorBelowThreshold();
        }
        bool minted = dsc.mint(msg.sender, _DscAmount);
        if (!minted) {
            revert DSC_TransferFailed();
        }
    }

    function checkingIfHealthFactorIsBelowThreshold(address user) internal view returns (bool) {
        if (calcualtingHealthFactor(user) < 1e18) {
            return false;
        }
        return true;
    }

    function calcualtingHealthFactor(address user) private view returns (uint256) {
        (uint256 dscBalance, uint256 collateralValue) = getAccountInformation(user);
        return (collateralValue * LIQUIDATION_THRESHOLD / ( 100 * dscBalance));
    }

    function getAccountInformation(address user) public view returns (uint256, uint256) {

        uint256 dscBalance = userDSCBalance[user];
        uint256 collateralValue = getUserCollateralValue(user);
        return (dscBalance, collateralValue);
    }

    function getUserCollateralValue(address user) public view returns (uint256) {
        uint256 totalCollateralValue = 0;
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            address token = collateralTokens[i];
            uint256 tokenBalance = userCollateralBalanceWithToken[user][token];
            uint256 tokenPrice = getUsdValueOfCollateral(token, tokenBalance);
            totalCollateralValue += tokenPrice;
        }
        return totalCollateralValue;
    }

    function getUsdValueOfCollateral(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(tokenPriceFeedMapping[token]);
        (,int price,,,) = priceFeed.latestRoundData();
        return (uint256(price) * (10**10) * amount) / (10**18);
    }
}