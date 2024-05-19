// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Errors} from "../libraries/Errors.sol";
import {EthAddressLib} from "../libraries/EthAddressLib.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {LendingPool} from "../core/LendingPool.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// REMOVE AFTER TESTING
import {console} from "forge-std/Test.sol";

/// @title Vault
/// @author YovchevYoan
/// @notice TODO
/// @dev Responsible for holding deposited tokens
contract Vault {
    using SafeERC20 for IERC20;

    /*///////////////////////////////////////////////
                    STATE VARIABLES
    ///////////////////////////////////////////////*/

    uint256 private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    uint256 private constant LIQUIDATION_BONUS = 10; // This means you get assets at a 10% discount when liquidating
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant FEED_PRECISION = 1e8;

    /// @notice The address of the lendingPool
    address private s_lendingPool;

    /// @notice Mapping holding users token balances
    mapping(address user => mapping(address token => uint256 amount))
        private s_lentDeposited;

    /// @dev Mapping traking user's deposited collateral
    // user => token => amount
    mapping(address user => mapping(address token => uint256 amount)) s_collateralDeposited;

    /// @dev Mapping traking user's borrow amount
    // user => token => amount
    mapping(address user => mapping(address token => uint256 amount)) s_amountBorrowed;

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

    /*///////////////////////////////////////////////
                EXTERNAL FUNCTIONS
    ///////////////////////////////////////////////*/

    /// @notice Transfers the deposited tokens to this Vault contract
    /// @param token The address of the token
    /// @param user The address of the user
    /// @param amount The amount deposited
    function lend(
        address token,
        address user,
        uint256 amount
    ) external payable onlyLendingPool {
        if (token != EthAddressLib.ethAddress()) {
            if (msg.value != 0) revert Errors.SendingETHWithERC20Transfer();

            s_lentDeposited[user][token] += amount;
            IERC20(token).safeTransferFrom(user, address(this), amount);
        } else {
            if (msg.value != amount)
                revert Errors.AmountAndValueSentDoNotMatch();
            s_lentDeposited[user][EthAddressLib.ethAddress()] += amount;
        }
    }

    function depositCollateral(
        address user,
        address token,
        uint256 amount
    ) external payable onlyLendingPool {
        if (token != EthAddressLib.ethAddress()) {
            if (msg.value != 0) revert Errors.SendingETHWithERC20Transfer();

            s_collateralDeposited[user][token] += amount;
            IERC20(token).safeTransferFrom(user, address(this), amount);
        } else {
            if (msg.value != amount)
                revert Errors.AmountAndValueSentDoNotMatch();
            s_collateralDeposited[user][EthAddressLib.ethAddress()] += amount;
        }
    }

    // check if this breaks the health factor
    function redeemCollatral(
        address user,
        address token,
        uint256 amount
    ) external onlyLendingPool {
        if (token != EthAddressLib.ethAddress()) {
            s_collateralDeposited[user][token] -= amount;
            IERC20(token).safeTransfer(user, amount);
        } else {
            s_collateralDeposited[user][EthAddressLib.ethAddress()] -= amount;
            // @question Check for reentrancy
            (bool success, ) = payable(user).call{value: amount}("");
            if (!success) revert Errors.TransferFailed();
        }
    }

    /// @notice Transfers lent tokens from the Vault contract to the user
    /// @param user The address of the user
    /// @param token The address of the token
    /// @param amount The amount to be transfered
    function withdraw(
        address user,
        address token,
        uint256 amount
    ) external onlyLendingPool {
        if (token != EthAddressLib.ethAddress()) {
            s_lentDeposited[user][token] -= amount;
            IERC20(token).safeTransfer(user, amount);
        } else {
            s_lentDeposited[user][EthAddressLib.ethAddress()] -= amount;
            // @question Check for reentrancy
            (bool success, ) = payable(user).call{value: amount}("");
            if (!success) revert Errors.TransferFailed();
        }
    }

    // move this to appropriate spot
    /*///////////////////////////////////////////////
                PUBLIC VIEW FUNCTIONS
    ///////////////////////////////////////////////*/

    /// @notice Gets the lent balance for the specified user and token
    /// @param token The address of the token
    /// @param user The address of the user
    function getLentDeposited(
        address user,
        address token
    ) public view returns (uint256) {
        return s_lentDeposited[user][token];
    }

    function liqudidate() external onlyLendingPool {}

    // CHECK HOW TO MAKE THIS CONTRACT WORK!!!

    function getHealthFactor() external returns (uint256) {
        return _healthFactor(msg.sender);
    }

    function getUserInformation(
        address user
    )
        public
        view
        returns (uint256 totalBorrowedAmountInUsd, uint256 collateralValueInUsd)
    {
        return _getAccountInformation(user);
    }

    // TODO Test this function!!!
    function _getAccountInformation(
        address user
    )
        private
        view
        returns (uint256 totalBorrowedAmountInUsd, uint256 collateralValueInUsd)
    {
        uint256 numberOfSupportedTokens = LendingPool(s_lendingPool)
            .getNumberOfSupportedTokens();
        for (uint256 i = 0; i < numberOfSupportedTokens; i++) {
            address token = LendingPool(s_lendingPool).getSupportedTokenInArray(
                i
            );
            uint256 amount = s_amountBorrowed[user][token];
            totalBorrowedAmountInUsd += getUsdValue(token, amount);
        }
        totalBorrowedAmountInUsd = getAccountCollateralValue(user);
        return (totalBorrowedAmountInUsd, collateralValueInUsd);
    }

    function calculateHealthFactor(
        uint256 totalBorrowedValue,
        uint256 collateralValueInUsd
    ) external pure returns (uint256) {
        return _calculateHealthFactor(totalBorrowedValue, collateralValueInUsd);
    }

    function getAccountCollateralValue(
        address user
    ) public view returns (uint256 totalCollateralValueInUsd) {
        uint256 numberOfSupportedTokens = LendingPool(s_lendingPool)
            .getNumberOfSupportedTokens();
        for (uint256 i = 0; i < numberOfSupportedTokens; i++) {
            address token = LendingPool(s_lendingPool).getSupportedTokenInArray(
                i
            );
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[token]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return
            ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function _healthFactor(address user) internal returns (uint256) {
        (
            uint256 totalDscMinted,
            uint256 collateralValueInUsd
        ) = _getAccountInformation(user);
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    function _calculateHealthFactor(
        uint256 totalBorrowedValue,
        uint256 collateralValueInUsd
    ) internal pure returns (uint256) {
        if (totalBorrowedValue == 0) return type(uint256).max; // What is this for?
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return
            (collateralAdjustedForThreshold * PRECISION) / totalBorrowedValue;
    }

    function _revertIfHealthFactorIsBroken(address user) internal {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR)
            revert Errors.BreaksHealthFactor(userHealthFactor);
    }

    function getAccountBalanceCollateral(
        address user,
        address token
    ) public view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function addTokenPriceFeed(
        address token,
        address priceFeed
    ) public onlyLendingPool returns (address, address) {
        s_priceFeeds[token] = priceFeed;
        return (token, priceFeed);
    }

    // @question do we need this function???
    receive() external payable {
        revert();
    }
}
