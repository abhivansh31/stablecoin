// The two invariants we can have a look on are : 
// 1. The value of the stablecoin is always and always less than the collateral deposited.
// 2. The getter view functions should not revert.

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStablecoin.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Handler} from "./Handler.t.sol";

contract HandlerInvariantsTest is StdInvariant ,Test {

    DecentralizedStableCoin dsc;
    DeployDSC deployDSC;
    DSCEngine dscEngine;
    HelperConfig config;
    address weth;
    address wtbc;
    Handler handler;

    function run() external {
        deployDSC = new DeployDSC();
        (dscEngine, dsc, config) = deployDSC.run();
        weth = config.getConfig().weth;
        wtbc = config.getConfig().wbtc;
        handler = new Handler(dsc, dscEngine);
        targetContract(address(handler));
        // targetContract(address(dscEngine));
    }

    function invariant_protocolMustHaveMoreValueThanCollateralDeposited() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalwethDeposited = IERC20(weth).balanceOf(address(dscEngine));
        uint256 totalwtbcDeposited = IERC20(wtbc).balanceOf(address(dscEngine));
        assert(totalSupply < totalwethDeposited + totalwtbcDeposited);
    }

    function invariant_getterViewFunctionsMustNotrevert() public view {
        dscEngine.getCollateralTokens();
    }
}