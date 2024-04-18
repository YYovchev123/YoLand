// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

contract InterestRateModel {
    /// @notice Interest rate precision
    uint256 public constant INTEREST_RATE_PRECISION = 1e18;

    /// @notice Base interest rate
    uint256 private s_baseInterestRate;

    /// @notice Constructor: sets the base interest rate
    constructor(uint256 baseInterestRate) {
        s_baseInterestRate = baseInterestRate;
    }

    /// @notice Calculates the current interest rate based on utilization ratio
    function getInterestRate(uint256 utilizationRatio) external view returns (uint256) {
        return s_baseInterestRate + utilizationRatio;
    }

    /// @notice Gets the base interest rate
    function getBaseInterestRate() external view returns (uint256) {
        return s_baseInterestRate;
    }
}
