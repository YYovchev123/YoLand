// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts@1.0.0/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Errors} from "../libraries/Errors.sol";

/// @title OracleLib
/// @author YovchevYoan
/// @notice A library for fetching price data from Chainlink price feeds.
/// @dev This library provides functions to fetch the latest price from a specified Chainlink price feed.
/// @dev It includes a timeout mechanism to prevent the use of stale price data.
library OracleLib {
    /// @notice The maximum time that the price should be updated within
    uint256 private constant TIMEOUT = 3 hours; // 3 * 60 * 60 = 10800 seconds

    /// @notice Fetches the latest price from the specified Chainlink price feed.
    /// @dev Reverts if the price data is stale or if the feed address is invalid.
    /// @param priceFeed The address of the Chainlink price feed contract.
    /// @return The latest price fetched from the price feed.
    function getChainlinkDataFeedLatestAnswer(AggregatorV3Interface priceFeed) public view returns (int256) {
        if (address(priceFeed) == address(0)) revert Errors.ZeroAddress();
        (, int256 answer,, uint256 updatedAt,) = priceFeed.latestRoundData();
        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) revert Errors.StalePrice();
        return answer;
    }
}
