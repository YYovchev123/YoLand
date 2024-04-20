// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Errors} from "../libraries/Errors.sol";

/// @title Token Contract
/// @author YovchevYoan
contract TokenContract {
    /*///////////////////////////////////////////////
                        EVENTS
    ///////////////////////////////////////////////*/

    /// @notice Emitted when tokens are transferred
    /// @param from The sender of the tokens
    /// @param to The recipient of the tokens
    /// @param amount The amount of tokens transferred
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /// @notice Emitted when a user approves another user to spend tokens on their behalf
    /// @param owner The user who approved the spender
    /// @param spender The user who was approved to spend tokens
    /// @param amount The amount of tokens approved to spend
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /// @notice Emitted when a user deposits tokens
    /// @param from The user who deposited tokens
    /// @param amount The amount of tokens deposited
    event Deposit(address indexed from, uint256 amount);

    /// @notice Emitted when a user withdraws tokens
    /// @param to The user who want to withdraw tokens
    /// @param amount The amount of tokens approved to spend
    event Withdraw(address indexed to, uint256 amount);

    /*///////////////////////////////////////////////
                    STORAGE VARIABLES
    ///////////////////////////////////////////////*/

    /// @notice The name of the token
    string private s_name;

    /// @notice The symbol of the token
    string private s_symbol;

    /// @notice The token decimals
    uint8 private immutable i_decimals;

    /// @notice The total supply of tokens.
    uint256 private s_totalSupply;

    /// @notice Token balances for each user
    mapping(address account => uint256 balance) private s_balanceOf;

    /// @notice Allowances for each user.
    /// @dev Indexed by owner, then by spender.
    mapping(address owner => mapping(address spender => uint256 amount)) private s_allowance;

    /*///////////////////////////////////////////////
                    CONSTRUCTOR
    ///////////////////////////////////////////////*/

    /// @notice Constructor: sets the name, symbol, decimals and totalSupply of the token
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param decimals The token decimals
    /// @param initialSupply The initial supply of tokens
    constructor(string memory name, string memory symbol, uint8 decimals, uint256 initialSupply) {
        /// @dev consider adding some checks
        s_name = name;
        s_symbol = symbol;
        i_decimals = decimals;
        s_totalSupply = initialSupply;
    }
    /*///////////////////////////////////////////////
                    EXTERNAL FUNCTIONS
    ///////////////////////////////////////////////*/

    /// @notice Allows a user to deposit a specified amount of tokens
    /// @param amount The amount of tokens a user wants to deposit
    /// @return Whether the deposit succeeded
    function deposit(uint256 amount) external returns (bool) {
        /// @dev should we check if the amount is firstly approved by the `msg.sender`???
        if (amount <= 0) revert Errors.InsufficientDeposit();

        unchecked {
            s_balanceOf[msg.sender] += amount;
            s_totalSupply += amount;
        }

        emit Deposit(msg.sender, amount);

        return true;
    }

    /// @notice Allows a user to withdraw a specified amount of tokens
    /// @param amount The amount of tokens a user wants to withdraw
    /// @return Whether the withdrawal succeeded
    function withdraw(uint256 amount) external returns (bool) {
        if (s_balanceOf[msg.sender] < amount) revert Errors.InsufficientBalance();

        s_balanceOf[msg.sender] -= amount;
        s_totalSupply -= amount;

        emit Withdraw(msg.sender, amount);

        return true;
    }

    /// @notice Transfers tokens from the caller to another user.
    /// @param to The user to transfer tokens to
    /// @param amount The amount of tokens to transfer
    /// @return Whether the transfer succeeded
    function transfer(address to, uint256 amount) external returns (bool) {
        if (s_balanceOf[msg.sender] < amount) revert Errors.InsufficientBalance();

        s_balanceOf[msg.sender] -= amount;
        unchecked {
            s_balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    /// @notice Transfers tokens from one user to another.
    /// @param from The user to transfer tokens from
    /// @param to The user to transfer tokens to
    /// @param amount The amount of tokens to transfer
    /// @return Whether the transfer succeeded
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowedAmount = s_allowance[from][msg.sender];
        if (allowedAmount < amount) revert Errors.InsufficientAllowance();
        if (allowedAmount != type(uint256).max) s_allowance[from][msg.sender] = allowedAmount - amount;

        s_balanceOf[from] -= amount;

        unchecked {
            s_balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /// @notice Approves a user to spend tokens on the caller's behalf.
    /// @param spender The user to approve
    /// @param amount The amount of tokens to approve
    /// @return Whether the approval succeeded
    function approve(address spender, uint256 amount) external returns (bool) {
        s_allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }
    /*///////////////////////////////////////////////
                PUBLIC VIEW FUNCTIONS
    ///////////////////////////////////////////////*/

    /// @notice Returns the amount that an owner has approved to the spender
    function allowance(address owner, address spender) public view returns (uint256) {
        return s_allowance[owner][spender];
    }

    /// @notice Returns the balance of a specified user
    function balanceOf(address user) public view returns (uint256) {
        return s_balanceOf[user];
    }

    /// @notice Returns the token name
    function getName() public view returns (string memory) {
        return s_name;
    }

    /// @notice Returns the token symbol
    function getSymbol() public view returns (string memory) {
        return s_symbol;
    }

    /// @notice Returns the token decimals
    function getDecimals() public view returns (uint8) {
        return i_decimals;
    }

    /// @notice Returns the total supply of tokens
    function getTotalSupply() public view returns (uint256) {
        return s_totalSupply;
    }
}
