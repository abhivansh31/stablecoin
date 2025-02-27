//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DecentralizedStablecoin} from "../src/DecentralizedStablecoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {Script, console} from "forge-std/Script.sol";

contract DeployDSC is Script {
    DecentralizedStablecoin public dsc;
    DSCEngine public dscEngine;

    function run() external returns(DSCEngine, DecentralizedStablecoin) {
        vm.startBroadcast();
        dsc = new DecentralizedStablecoin();
        dscEngine = new DSCEngine(address(dsc));
        vm.stopBroadcast();
        return (dsc, dscEngine);
    }
}