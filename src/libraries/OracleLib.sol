//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library OracleLib {

    error OracleLib__Timeout();

    uint256 constant TIMEOUT = 3 hours; 

    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed) public view returns(uint80, int256, uint256, uint256, uint80) {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData(); 

        uint256 secondspassed = block.timestamp - updatedAt;
        if (secondspassed > TIMEOUT) {
            revert OracleLib__Timeout();
        }
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}