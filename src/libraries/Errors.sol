// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

library Errors {
    /// @notice TokenContract, yToken: When a user inputs an amount greater than his balance
    error InsufficientBalance();

    /// @notice TokenContract: When a user tries to deposit the amount less or equal to `0`
    error InsufficientDeposit();

    /// @notice TokenContract: When a user tries to transfer from an amount bigger than the allowance
    error InsufficientAllowance();

    /// @notice yToken: When function is not called by the lending platfrom
    error onlyLendingPlatform();

    /// @notice yToken: When the invariant of exchangeRate can only increase is broken
    error ExhangeRateCanOnlyIncrease(uint256 oldExchangeRate, uint256 newExchangeRate);

    /// @notice yToken: Reverts on address(0)
    error ZeroAddress();

    /// @notice OracleContract: Reverts when a price has not been updated for a specified amount of time
    error StalePrice();

    /// @notice LendingPool: Reverts if the provided token address is not supported
    error TokenNotSupported();

    /// @notice LendingPool: Reverts if the provided token does not have its YToken configured
    error YTokenNotConfigured();

    /// @notice LendingPool: Reverts if a transfer fails
    error TransferFailed();

    /// @notice LendingPool: Reverts if a deposit fails
    error DepositFailed();
}
