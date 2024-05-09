// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Errors} from "../libraries/Errors.sol";
import {EthAddressLib} from "../libraries/EthAddressLib.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

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

    /// @notice The address of the lendingPool
    address private s_lendingPool;

    /// @notice Mapping holding users token balances
    mapping(address user => mapping(address token => uint256 amount)) private balanceOf;

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
    function transferTokenToVault(address token, address user, uint256 amount) external payable onlyLendingPool {
        if (token != EthAddressLib.ethAddress()) {
            if (msg.value != 0) revert Errors.SendingETHWithERC20Transfer();

            balanceOf[user][token] += amount;
            IERC20(token).safeTransferFrom(user, address(this), amount);
        } else {
            if (msg.value != amount) revert Errors.AmountAndValueSentDoNotMatch();
            balanceOf[user][EthAddressLib.ethAddress()] += amount;
        }
    }

    /// @notice Transfers tokens from the Vault contract to the user
    /// @param user The address of the user
    /// @param token The address of the token
    /// @param amount The amount to be transfered
    function transferTokenToUser(address user, address token, uint256 amount) external {
        if (token != EthAddressLib.ethAddress()) {
            balanceOf[user][token] -= amount;
            IERC20(token).safeTransferFrom(address(this), user, amount);
        } else {
            balanceOf[user][EthAddressLib.ethAddress()] -= amount;
            // @question Check for reentrancy
            (bool success,) = payable(user).call{value: amount}("");
            if (!success) revert Errors.TransferFailed();
        }
    }

    /*///////////////////////////////////////////////
                PUBLIC VIEW FUNCTIONS
    ///////////////////////////////////////////////*/

    /// @notice Gets the balance for the specified user and token
    /// @param token The address of the token
    /// @param user The address of the user
    function getBalance(address user, address token) public view returns (uint256) {
        return balanceOf[user][token];
    }

    // @question do we need this function???
    // receive() external payable {}
}
