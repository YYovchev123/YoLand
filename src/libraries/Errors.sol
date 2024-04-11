// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.18;

library Errors {
    /// @notice TokenContract, yToken: When a user inputs an amount greater than his balance
    error InsufficientBalance();

    /// @notice TokenContract: When a user tries to deposit the amount less or equal to `0`
    error InsufficientDeposit();

    /// @notice yToken: When a transaction is not successful
    error NotSuccessful();
}
