//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DecentralizedStablecoin} from "./DecentralizedStablecoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";



contract DSCEngine is ReentracyGuard { 
    DecentralizedStablecoin public dsc;

    error TokenAddressAndPriceFeedAddressArrayMustBeSameLength();
    error TokenNotSupported();
    error AmountLessThanZero();
    error TransferFailed();

    mappping(address token => address priceFeed) public tokenPriceFeedMapping;
    mappping(address user => (mappping(address token => uint256)) public userCollateralBalance) public userCollateralBalanceWithToken;

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
}