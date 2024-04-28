// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {OracleLib} from "../libraries/OracleLib.sol";
import {TokenContract} from "../main/TokenContract.sol";
import {InterestRateModel} from "../core/InterestRateModel.sol";
import {YToken} from "../main/YToken.sol";
import {Errors} from "../libraries/Errors.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Owned} from "@solmate/src/auth/Owned.sol";

// TODO add natspec to LendingPool
contract LendingPool is Owned(msg.sender) {
    using OracleLib for AggregatorV3Interface;

    /// @notice Interest rate model contract determining interest rates
    InterestRateModel private interestRateModel;

    /// @notice Mapping of supported tokens
    mapping(address tokenAddress => TokenContract) private s_supportedTokens;

    /// @notice Mapping -> token corresponding to its YToken
    mapping(address token => YToken yToken) private s_tokenToYToken;

    constructor(address interestRateModelAddress) {
        interestRateModel = InterestRateModel(interestRateModelAddress);
    }

    modifier isSupportedToken(address token) {
        if (address(s_supportedTokens[token]) == address(0)) revert Errors.TokenNotSupported();
        _;
    }

    function modifySupportedToken(address tokenAddress) public onlyOwner {
        s_supportedTokens[tokenAddress] = TokenContract(tokenAddress);
    }

    function configureTokenToYToken(address token, address yToken) public onlyOwner {
        s_tokenToYToken[token] = YToken(yToken);
    }

    // Make sure all this function works correctly and everything is good
    function deposit(address token, uint256 amount) external isSupportedToken(token) {
        TokenContract tokenContract = s_supportedTokens[token];
        YToken yToken = s_tokenToYToken[token];
        if (address(s_tokenToYToken[token]) == address(0)) revert Errors.YTokenNotConfigured();

        if (!tokenContract.transferFrom(msg.sender, address(this), amount)) revert Errors.TransferFailed();
        if (!tokenContract.deposit(amount)) revert Errors.DepositFailed();

        uint256 cTokenAmount = amount / yToken.getExchangeRate();
        yToken.mint(msg.sender, cTokenAmount);
    }

    function withdrawal(address token, uint256 amount) external isSupportedToken(token) {}

    function borrow() public {}

    function repay() public {}

    function liquidation() public {}
}
