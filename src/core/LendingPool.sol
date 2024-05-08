// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {OracleLib} from "../libraries/OracleLib.sol";
import {InterestRateModel} from "../core/InterestRateModel.sol";
import {YToken} from "../main/YToken.sol";
import {Errors} from "../libraries/Errors.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Vault} from "./Vault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title LendingPool
/// @author YovchevYoan
/// @notice TODO
/// @dev Responsible for TODO
contract LendingPool is Ownable(msg.sender) {
    event Deposit(address indexed user, uint256 amount);
    event SupportedToken(address indexed token, address yToken, bool isSupported);
    event Withdraw(address indexed user, address token, uint256 amountYToken, uint256 tokenAmount);

    Vault private s_vault;

    /// @notice Fee parameter: 0.03 %
    uint256 private constant FEE = 3e15;
    uint256 private constant FEE_PRECISION = 1e18;

    mapping(address token => address yToken) private s_tokenToYToken;
    mapping(address token => bool isSupported) private s_supportedTokens;

    /// @dev It may cost a lot of gas to initialize the contract
    constructor(address vault, address[] memory supportedTokens) {
        s_vault = Vault(vault);

        /// @dev CHECK THIS AND SEE IF IT IS A GOOD IDEA!!!
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            setSupporedToken(supportedTokens[i], true);
        }
    }

    modifier revertIfZero(uint256 amount) {
        if (amount == 0) revert Errors.AmountCannotBeZero();
        _;
    }

    modifier revertIfTokenNotSupported(address token) {
        if (!isSupportedToken(token)) revert Errors.TokenNotSupported();
        _;
    }

    function deposit(address token, uint256 amount) external revertIfZero(amount) revertIfTokenNotSupported(token) {
        YToken yToken = YToken(s_tokenToYToken[token]);

        uint256 mintAmount = (amount * yToken.EXCHANGE_RATE_PRECISION()) / yToken.getExchangeRate();
        if (mintAmount == 0) revert Errors.AmountCannotBeZero();

        yToken.mint(msg.sender, mintAmount);

        s_vault.transferTokenToVault(token, msg.sender, amount);
        emit Deposit(msg.sender, amount);
    }

    function withdraw(address token, uint256 amountYToken)
        external
        revertIfZero(amountYToken)
        revertIfTokenNotSupported(token)
    {
        YToken yToken = YToken(s_tokenToYToken[token]);
        if (amountYToken == type(uint256).max) {
            amountYToken = s_vault.getBalance(msg.sender, token);
        }
        // The amount of underlying token to transfer to the user
        uint256 tokenAmount = (amountYToken * yToken.getExchangeRate()) / yToken.EXCHANGE_RATE_PRECISION();
        yToken.burn(msg.sender, amountYToken);
        s_vault.transferTokenToUser(msg.sender, token, tokenAmount);
        emit Withdraw(msg.sender, token, amountYToken, tokenAmount);
    }

    /// @dev If the token does not have a name or a symbol, this could be an issue
    function setSupporedToken(address token, bool isSupported) public onlyOwner returns (address) {
        if (isSupported) {
            if (s_tokenToYToken[token] != address(0)) revert Errors.YTokenAlreadySupported(token);

            // @audit Will the `name` and `symbol` functions work for the ETH address provided in `EthAddressLib.sol`
            string memory name = string.concat("YToken ", IERC20Metadata(address(token)).name());
            string memory symbol = string.concat("Y", IERC20Metadata(address(token)).symbol());
            YToken yToken = new YToken(address(this), token, name, symbol);
            s_tokenToYToken[token] = address(yToken);
            s_supportedTokens[token] = isSupported;
            emit SupportedToken(token, address(yToken), isSupported);
            return address(yToken);
        } else {
            YToken yToken = YToken(s_tokenToYToken[token]);
            s_supportedTokens[token] = isSupported;
            delete s_tokenToYToken[token];
            emit SupportedToken(token, address(yToken), isSupported);
            return address(yToken);
        }
    }

    function isSupportedToken(address token) public view returns (bool) {
        return s_supportedTokens[token];
    }
}
