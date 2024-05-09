// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Errors} from "../libraries/Errors.sol";
import {EthAddressLib} from "../libraries/EthAddressLib.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "../libraries/OracleLib.sol";

/// @title InterestRateModel
/// @author YovchevYoan
/// @notice This contract is responsible for tracking users collateral
contract CollateralTracker {
    using SafeERC20 for IERC20;
    using OracleLib for AggregatorV3Interface;

    /*///////////////////////////////////////////////
                    STATE VARIABLES
    ///////////////////////////////////////////////*/

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;

    /// @notice The address of the lendingPool
    address private s_lendingPool;

    /// @dev Mapping traking user's s_collateralDeposited
    // user => token => amount
    mapping(address user => mapping(address token => uint256 amount)) s_collateralDeposited;
    /// @dev Mapping tracking token to price feed
    // token => price feed
    mapping(address token => address priceFeed) private s_priceFeeds;

    /*///////////////////////////////////////////////
                    CONSTRUCTOR
    ///////////////////////////////////////////////*/

    /// @notice Constructor: sets the lendingPool
    /// @param lendingPool The address of the lendingPool
    constructor(address lendingPool) {
        s_lendingPool = lendingPool;
    }

    /*///////////////////////////////////////////////
                    MODIFIERS
    ///////////////////////////////////////////////*/

    /// @notice Allows a function to be called only by the LendingPool
    modifier onlyLendingPool() {
        if (msg.sender != s_lendingPool) revert Errors.onlyLendingPool();
        _;
    }

    function transferCollateralToTracker(address user, address token, uint256 amount)
        external
        payable
        onlyLendingPool
    {
        if (token != EthAddressLib.ethAddress()) {
            s_collateralDeposited[user][token] -= amount;
            IERC20(token).safeTransfer(user, amount);
        } else {
            s_collateralDeposited[user][EthAddressLib.ethAddress()] -= amount;
            // @question Check for reentrancy
            (bool success,) = payable(user).call{value: amount}("");
            if (!success) revert Errors.TransferFailed();
        }
    }

    function liqudidate() external onlyLendingPool {}

    // CHECK HOW TO MAKE THIS CONTRACT WORK!!!

    function getHealthFactor() external returns (uint256) {
        return _healthFactor(msg.sender);
    }

    function getUserInformation(address user) public returns (uint256, uint256) {}

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {}

    function calculateHealthFactor(uint256 totalBorrowedValue, uint256 collateralValueInUsd)
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalBorrowedValue, collateralValueInUsd);
    }

    function getCollateralValue(address user) public view returns (uint256) {}

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // 1 ETH = $1000
        // The returned value from CL will be 1000 * 1e8
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function _healthFactor(address user) internal returns (uint256) {}

    function _calculateHealthFactor(uint256 totalBorrowedValue, uint256 collateralValueInUsd)
        internal
        pure
        returns (uint256)
    {}

    function _revertIfHealthFactorIsBroken(address user) internal view {}

    function getBalance(address user, address token) public view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function addTokenPriceFeed(address token, address priceFeed) public onlyLendingPool returns (address, address) {
        s_priceFeeds[token] = priceFeed;
        return (token, priceFeed);
    }
}
