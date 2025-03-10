//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DecentralizedStableCoin} from "../src/DecentralizedStablecoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script {
    DecentralizedStableCoin public dsc;
    DSCEngine public dscEngine;
    address[] tokenAddresses;
    address[] priceFeedAddresses;

    function run() external returns(DSCEngine, DecentralizedStableCoin, HelperConfig) {
        HelperConfig config = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();
        address wethAddress = networkConfig.weth;
        address wbtcAddress = networkConfig.wbtc;
        address wbtcPriceFeedAddress = networkConfig.wbtcUsdPriceFeed;
        address wethPriceFeedAddress = networkConfig.wethUsdPriceFeed;
        uint256 deployerKey = networkConfig.deployerKey;
        tokenAddresses = [wethAddress, wbtcAddress];
        priceFeedAddresses = [wethPriceFeedAddress, wbtcPriceFeedAddress];
        vm.startBroadcast(deployerKey);
        dsc = new DecentralizedStableCoin();
        dscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses ,address(dsc));
        dsc.transferOwnership(address(dscEngine));
        vm.stopBroadcast();
        return (dscEngine, dsc, config);
    }
}