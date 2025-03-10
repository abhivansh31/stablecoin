// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    uint256 private constant DECIMALS = 8;
    uint256 private constant ETH_USD_PRICE = 3000e8;
    uint256 private constant BTC_USD_PRICE = 90000e8;
    uint256 private DEFAULT_ANVIL_PRIVATE_KEY = vm.envUint("ANVIL_PRIVATE_KEY"); 
    uint256 private DEFAULT_PRIVATE_KEY = vm.envUint("DEPLOYER_PRIVATE_KEY");

    address private immutable WETH_PRICE_FEED_ADDRESS = vm.envAddress("WETH_PRICE_FEED_ADDRESS");
    address private immutable WBTC_PRICE_FEED_ADDRESS = vm.envAddress("WBTC_PRICE_FEED_ADDRESS");
    address private immutable WETH_ADDRESS = vm.envAddress("WETH_ADDRESS");
    address private immutable WBTC_ADDRESS = vm.envAddress("WBTC_ADDRESS");

    function getConfig() public returns (NetworkConfig memory) {
        return getOrCreateConfig(block.chainid);
    }

    function getOrCreateConfig(uint256 chainId) public returns(NetworkConfig memory config){
        if (chainId == 11155111) {
            config = getSepoliaEthConfig();
            return config;
        } else if (chainId == 31337) {
            config = getOrCreateAnvilEthConfig();
            return config;
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig(
            WETH_PRICE_FEED_ADDRESS, 
            WBTC_PRICE_FEED_ADDRESS,
            WETH_ADDRESS,
            WBTC_ADDRESS,
            DEFAULT_PRIVATE_KEY
        );
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        // Check to see if we set an active network config
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        ERC20Mock wethMock = new ERC20Mock();

        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20Mock wbtcMock = new ERC20Mock();
        vm.stopBroadcast();

        anvilNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: address(ethUsdPriceFeed),
            wbtcUsdPriceFeed: address(btcUsdPriceFeed),
            weth: address(wethMock),
            wbtc: address(wbtcMock),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });

        activeNetworkConfig = anvilNetworkConfig;
        return anvilNetworkConfig;
    }
}