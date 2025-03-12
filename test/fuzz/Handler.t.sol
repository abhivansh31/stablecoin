//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStablecoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {

    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;
    ERC20Mock weth;
    ERC20Mock wbtc;
    address[] public userWithCollateralDeposited;

    constructor(DecentralizedStableCoin _stablecoin, DSCEngine _engine) {
        dsc = _stablecoin;
        dscEngine = _engine;
        address[] memory tokens = _engine.getCollateralTokens();
        weth = ERC20Mock(tokens[0]);
        wbtc = ERC20Mock(tokens[1]);
    }

    function depositCollateral(uint256 collateralSeed, uint256 amount) external {
        address collateralTokenAddress = selectCollateralToken(collateralSeed);
        amount = bound(amount, 1, type(uint96).max);
        vm.startPrank(msg.sender);
        ERC20Mock(collateralTokenAddress).mint(msg.sender, amount);
        ERC20Mock(collateralTokenAddress).approve(address(dscEngine), amount);
        dscEngine.depositCollateral(collateralTokenAddress, amount);
        vm.stopPrank();
        userWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amount) external {
        address collateralTokenAddress = selectCollateralToken(collateralSeed);
        uint256 maximumCollateral = dscEngine.getCollateralBalanceOfUser(msg.sender, collateralTokenAddress);
        amount = bound(amount, 0, maximumCollateral);
        if (amount == 0) {
            return;
        }
        dscEngine.redeemCollateral(collateralTokenAddress, amount);
    }

    function mintDsc(uint256 amount, uint256 amountSeed) external {
        address sender = userWithCollateralDeposited[amountSeed % userWithCollateralDeposited.length];
        if (userWithCollateralDeposited.length == 0) {
            return;
        }
        (uint256 dscAmount, uint256 collateralAmount) = dscEngine.getAccountInformation(sender);
        int256 maxDscMinted = (int256(collateralAmount)/2) - int256(dscAmount);
        if (maxDscMinted <= 0) {
            return;
        }
        amount = bound(amount, 0, uint256(maxDscMinted));
        if (amount == 0) {
            return;
        }
        vm.startPrank(sender);
        dscEngine.mintDsc(amount);
        vm.stopPrank();
    }

    function selectCollateralToken(uint256 collateralSeed) private view returns(address){
        address collateralTokenAddress = collateralSeed % 2 == 0 ? address(weth) : address(wbtc);
        return collateralTokenAddress;
    }
}