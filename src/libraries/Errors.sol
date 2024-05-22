// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

/// @title Errors
/// @author YovchevYoan
/// @notice A library containing all the errors
library Errors {
    /// @notice TokenContract, yToken: When a user inputs an amount greater than his balance
    error InsufficientBalance();

    /// @notice TokenContract: When a user tries to deposit the amount less or equal to `0`
    error InsufficientDeposit();

    /// @notice TokenContract: When a user tries to transfer from an amount bigger than the allowance
    error InsufficientAllowance();

    /// @notice yToken, LPManager: When function is not called by the lending pool
    error onlyLendingPool();

    /// @notice yToken: When the invariant of exchangeRate can only increase is broken
    error ExhangeRateCanOnlyIncrease(uint256 oldExchangeRate, uint256 newExchangeRate);

    /// @notice yToken: Reverts on address(0)
    error ZeroAddress();

    /// @notice LendingPool: Reverts on an amount being 0
    error AmountCannotBeZero();

    /// @notice OracleContract: Reverts when a price has not been updated for a specified amount of time
    error StalePrice();

    /// @notice LendingPool: Reverts if the provided token address is not supported
    error TokenNotSupported();

    /// @notice LendingPool: Reverts if the procided token has already been supported
    error YTokenAlreadySupported(address token);

    /// @notice LendingPool: Reverts if the provided token does not have its YToken configured
    error YTokenNotConfigured();

    /// @notice LendingPool, LPManager: Reverts if a transfer fails
    error TransferFailed();

    /// @notice LendingPool: Reverts if a deposit fails
    error DepositFailed();

    /// @notice LendingPool: Reverts when initializedLPManager has already been called
    error AlreadyInitialized();

    /// @notice LPManager: Reverts when an ERC20 transfer is called with msg.vaule > 0
    error SendingETHWithERC20Transfer();

    /// @notice LPManager: Reverts when the amount and the provided value do not match
    error AmountAndValueSentDoNotMatch();

    error ValueSendWithNonETHToken();

    /// @notice LPManager: Reverts when health factor is broken
    error BreaksHealthFactor(uint256);

    /// @notice LPManager: Reverts if the `liquidate` function is called on a healthy account
    error HealthFactorOk();

    /// @notice LPManager: Reverts when there is not enough collateral to be seized from the borrower
    error NotEnoughCollateralToSeize();
}
