//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DecentralizedStablecoin} from "./DecentralizedStablecoin.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract DSCEngine is ReentrancyGuard { 
    DecentralizedStablecoin public dsc;

    error TokenAddressAndPriceFeedAddressArrayMustBeSameLength();
    error TokenNotSupported();
    error AmountLessThanZero();
    error TransferFailed();
    error HealthFactorBelowThreshold();

    uint256 private constant LIQUIDATION_THRESHOLD = 50;

    mapping(address token => address priceFeed) public tokenPriceFeedMapping;
    mapping(address user => mapping(address token => uint256)) public userCollateralBalanceWithToken;
    mapping(address user => uint256 tokens) private userDSCBalance;
    address[] private collateralTokens;

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address dscAddress 
    ) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert TokenAddressAndPriceFeedAddressArrayMustBeSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            tokenPriceFeedMapping[tokenAddresses[i]] = priceFeedAddresses[i];
            collateralTokens.push(tokenAddresses[i]);
        }

        dsc = DecentralizedStablecoin(dscAddress);
    }

    function depositCollateral(address collateralTokenAddress, uint256 collateralAmount) public nonReentrant {
        if (tokenPriceFeedMapping[collateralTokenAddress] == address(0)) {
            revert TokenNotSupported();
        }
        if (collateralAmount <= 0) {
            revert AmountLessThanZero();
        }
        userCollateralBalanceWithToken[msg.sender][collateralTokenAddress] += collateralAmount;
        emit CollateralDeposited(msg.sender, collateralTokenAddress, collateralAmount);
        bool successfulTransaction = IERC20(collateralTokenAddress).transferFrom(msg.sender, address(this), collateralAmount);
        if (!successfulTransaction) {
            revert TransferFailed();
        }
    }

    function mintDsc (uint256 _DscAmount) public nonReentrant {
        if (_DscAmount <= 0) {
            revert AmountLessThanZero();
        }
        userDSCBalance[msg.sender] += _DscAmount;
        if (!checkingIfHealthFactorIsBelowThreshold(msg.sender)) {
            revert HealthFactorBelowThreshold();
        }
        bool minted = dsc.mint(msg.sender, _DscAmount);
        if (!minted) {
            revert TransferFailed();
        }
    }

    function checkingIfHealthFactorIsBelowThreshold(address user) internal view returns (bool) {
        if (calcualtingHealthFactor(user) < 1) {
            return false;
        }
        return true;
    }

    function calcualtingHealthFactor(address user ) private view returns (uint256) {
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
        uint256 adjustedPrice = uint256(price) * (10**10);
        return (adjustedPrice * amount) / (10**18);
    }
}