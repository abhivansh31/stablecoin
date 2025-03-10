//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
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
    address weth;

    address user = makeAddr("user");

    function setUp() external {
        deployDSC = new DeployDSC();
        (dscEngine, dsc, config) = deployDSC.run();
        weth = config.getConfig().weth;
        ethUsdPriceFeed = config.getConfig().wethUsdPriceFeed;
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
}

