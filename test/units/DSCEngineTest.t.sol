//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStablecoin.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DecentralizedStableCoin dsc;
    DeployDSC deployDSC;
    DSCEngine dscEngine;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address wbtc;
    address weth;
    address[] tokenAddress;
    address[] priceFeedAddresses;
    uint256 constant AMOUNT_BALANCE = 10 ether;

    address user = makeAddr("user");

    modifier depositCollateral() {
        tokenAddress.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_BALANCE);
        dscEngine.depositCollateral(weth, AMOUNT_BALANCE);
        vm.stopPrank();
        _;
    }

    function setUp() external {
        deployDSC = new DeployDSC();
        (dscEngine, dsc, config) = deployDSC.run();
        weth = config.getConfig().weth;
        ethUsdPriceFeed = config.getConfig().wethUsdPriceFeed;
        btcUsdPriceFeed = config.getConfig().wbtcUsdPriceFeed;
        wbtc = config.getConfig().wbtc;
        ERC20Mock(weth).mint(user, 10 ether);
    }

    function testEthUsdValue() external view {
        uint256 ethAmount = 15e18;
        uint256 expectedEth = 45000e18;
        uint256 actualEth = dscEngine.getUsdValueOfCollateral(weth, ethAmount);
        assertEq(expectedEth, actualEth);
    }

    function testRevertIfCollateralIsZero() external {
        vm.prank(user);
        ERC20Mock(weth).approve(address(dscEngine), 10 ether);
        vm.expectRevert();
        dscEngine.depositCollateral(weth, 0);
    }

    function testRevertIfLengthOfTokenFeedAddressesndPriceFeedAddressesDontMatch()
        external
    {
        tokenAddress.push(wbtc);
        priceFeedAddresses.push(btcUsdPriceFeed);
        priceFeedAddresses.push(ethUsdPriceFeed);
        vm.expectRevert();
        DSCEngine newDscEngine = new DSCEngine(
            tokenAddress,
            priceFeedAddresses,
            address(dsc)
        );
    }

    function testGetTokenAmountFromUsd() external view {
        uint256 usdAmount = 30 ether;
        uint256 expectedValue = 0.01 ether;
        uint256 actualValue = dscEngine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedValue, actualValue);
    }

    function testRevertIfTokenUnsupported() external {
        ERC20Mock randomToken = new ERC20Mock();
        randomToken.mint(user, 10 ether);
        vm.prank(user);
        vm.expectRevert();
        dscEngine.depositCollateral(address(randomToken), 10 ether);
    }

    function testDepositCollateral() external depositCollateral {
        (uint256 dscBalance, uint256 collateralValue) = dscEngine
            .getAccountInformation(user);
        uint256 expectedDscBalance = 0;
        uint256 expectedCollateralValue = dscEngine.getTokenAmountFromUsd(
            weth,
            collateralValue
        );
        assertEq(expectedDscBalance, dscBalance);
        assertEq(AMOUNT_BALANCE, expectedCollateralValue);
    }

    function testGetUserCollateralValue() external depositCollateral {
        uint256 value = dscEngine.getUserCollateralValue(user);
        uint256 expectedValue = 30000 ether;
        assertEq(expectedValue, value);
    }

    function testMintDscWillFailWithHealthFactorBelowThreshold()
        external
        depositCollateral
    {
        vm.prank(user);
        vm.expectRevert();
        dscEngine.mintDsc(10 ether);
    }    
}
