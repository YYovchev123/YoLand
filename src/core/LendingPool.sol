// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {OracleLib} from "../libraries/OracleLib.sol";
import {InterestRateModel} from "../core/InterestRateModel.sol";
import {YToken} from "./YToken.sol";
import {Errors} from "../libraries/Errors.sol";
import {EthAddressLib} from "../libraries/EthAddressLib.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {LPManager} from "./LPManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {InterestRateModel} from "./InterestRateModel.sol";

// REMOVE AFTER TESTING
import {console} from "forge-std/Test.sol";

/// @title LendingPool
/// @author YovchevYoan
/// @notice TODO
/// @dev Responsible for TODO
contract LendingPool is Ownable(msg.sender), ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;

    /*///////////////////////////////////////////////
                        EVENTS
    ///////////////////////////////////////////////*/

    /// @notice Emitted when a user deposits
    /// @param user The new exchange rate
    /// @param amount The amount deposited
    event Deposit(address indexed user, uint256 amount);

    /// @notice Emitted when the state of a token is changed
    /// @param token The address of the token
    /// @param yToken The address of the corresponding YToken
    /// @param isSupported Whether or not the token is supported
    event SupportedToken(address indexed token, address yToken, bool isSupported);

    /// @notice Emitted when a user withdraws
    /// @param user The user who withdrew
    /// @param token The address of the token
    /// @param amountYToken The amount of yToken burnt
    /// @param tokenAmount The amount of token redeemed by the user
    event Withdraw(address indexed user, address token, uint256 amountYToken, uint256 tokenAmount);

    /// @notice Emitted when a price feed address is added to token
    /// @param token The address of the token
    /// @param priceFeed The address of the price feed
    event TokenPriceFeedAdded(address indexed token, address priceFeed);

    /*///////////////////////////////////////////////
                    STATE VARIABLES
    ///////////////////////////////////////////////*/

    /// @notice The LPManager in which tokens are stored
    LPManager private s_lpManager;
    /// @notice The interest rate model contract
    InterestRateModel private s_interestRateModel;

    /// @notice Bool whether the LPManager has been initialized or not
    bool initialized;

    /// @dev Mapping traking the address of the token to the address
    // of its yToken | token => yToken
    mapping(address token => address yToken) private s_tokenToYToken;

    /// @dev An EnumberableSet of Addresses containing all the supported tokens
    EnumerableSet.AddressSet private s_supportedTokens;

    /// FOR EXAMINATION

    /*///////////////////////////////////////////////
                    CONSTRUCTOR
    ///////////////////////////////////////////////*/

    /// @notice Constructor: sets the InterestRateModel address and the initial supported tokens
    /// @param interestRateModel The address of InterestRateModel contract
    /// @param supportedTokens The initial supported tokens
    constructor(address interestRateModel, address[] memory supportedTokens) {
        s_interestRateModel = InterestRateModel(interestRateModel);

        /// @dev CHECK THIS AND SEE IF IT IS A GOOD IDEA!!!
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            addSupportedToken(supportedTokens[i]);
        }
    }

    /*///////////////////////////////////////////////
                    MODIFIERS
    ///////////////////////////////////////////////*/

    /// @notice Reverts if the given amount if zero / (0)
    /// @param amount The amount to be checked
    modifier revertIfZero(uint256 amount) {
        if (amount == 0) revert Errors.AmountCannotBeZero();
        _;
    }

    /// @notice Reverts if the token provided is not supported
    /// @param token The address of the token to be checked
    modifier revertIfTokenNotSupported(address token) {
        if (!isSupportedToken(token)) revert Errors.TokenNotSupported();
        _;
    }

    /*///////////////////////////////////////////////
                    EXTERNAL FUCTIONS
    ///////////////////////////////////////////////*/

    /// @notice This function sets up the LPManager contract
    /// @dev This function will be called right after contract deployment
    /// so the protocol does not break
    /// @param lpManager The LPManager address
    function initializesLPManager(address lpManager) external onlyOwner {
        if (initialized) revert Errors.AlreadyInitialized();
        s_lpManager = LPManager(payable(lpManager));
        initialized = true;
    }

    /// @notice Called by users wanting to lend tokens into the protocol
    /// @dev This function mint YTokens to the lenders determined by the YToken's
    /// exchange rate
    /// @dev The function reverts if value is sent and the token is not ETH
    /// @param token The address of the token
    /// @param amount The amount of tokens to be lenders
    function lend(address token, uint256 amount)
        external
        payable
        revertIfZero(amount)
        revertIfTokenNotSupported(token)
        nonReentrant
    {
        if (msg.value > 0 && token != EthAddressLib.ethAddress()) {
            revert Errors.ValueSendWithNonETHToken();
        }
        YToken yToken = YToken(s_tokenToYToken[token]);

        uint256 mintAmount = (amount * yToken.EXCHANGE_RATE_PRECISION()) / yToken.getExchangeRate();
        // @question is there any way for a potential DOS here???
        if (mintAmount == 0) revert Errors.AmountCannotBeZero();

        yToken.mint(msg.sender, mintAmount);

        s_lpManager.lend{value: msg.value}(token, msg.sender, amount);
        emit Deposit(msg.sender, amount);
    }

    /// @notice Called by users wanting to withdraw their provided tokens to the protocol
    /// @dev This function calculates the amount of tokens based on the provided amount
    /// of YTokens and it's exchange rate
    /// @dev The function burns the provided amount of YToken
    /// @param token The address of the token
    /// @param amountYToken The amount of YTokens provided for withdrawal
    function withdraw(address token, uint256 amountYToken)
        external
        revertIfZero(amountYToken)
        revertIfTokenNotSupported(token)
        nonReentrant
    {
        YToken yToken = YToken(s_tokenToYToken[token]);
        if (amountYToken == type(uint256).max) {
            amountYToken = s_lpManager.getLentDeposited(msg.sender, token);
        }
        // The amount of underlying token to transfer to the user
        uint256 tokenAmount = (amountYToken * yToken.getExchangeRate()) / yToken.EXCHANGE_RATE_PRECISION();

        yToken.burn(msg.sender, amountYToken);
        s_lpManager.withdraw(msg.sender, token, tokenAmount);

        emit Withdraw(msg.sender, token, amountYToken, tokenAmount);
    }

    function depositCollateral(address token, uint256 amount)
        external
        payable
        revertIfZero(amount)
        revertIfTokenNotSupported(token)
        nonReentrant
    {
        if (msg.value > 0 && token != EthAddressLib.ethAddress()) {
            revert Errors.ValueSendWithNonETHToken();
        }
        s_lpManager.depositCollateral{value: msg.value}(msg.sender, token, amount);
    }

    function borrow(address token, uint256 amount) external nonReentrant {}

    function repay(address token, uint256 amount) external nonReentrant {}

    function liquidate(address user, address debtToken, uint256 debtToCover, address collateralToken)
        external
        nonReentrant
    {}

    function addSupportedToken(address token) public onlyOwner returns (address) {
        if (s_tokenToYToken[token] != address(0)) {
            revert Errors.YTokenAlreadySupported(token);
        }
        if (token == EthAddressLib.ethAddress()) {
            string memory name = "YToken ETH";
            string memory symbol = "YETH";
            YToken yToken = new YToken(address(this), token, name, symbol);
            s_tokenToYToken[token] = address(yToken);
            s_supportedTokens.add(token);
            emit SupportedToken(token, address(yToken), true);
            return address(yToken);
        } else {
            string memory name = string.concat("YToken ", IERC20Metadata(address(token)).name());
            string memory symbol = string.concat("Y", IERC20Metadata(address(token)).symbol());
            YToken yToken = new YToken(address(this), token, name, symbol);
            s_tokenToYToken[token] = address(yToken);
            s_supportedTokens.add(token);
            emit SupportedToken(token, address(yToken), true);
            return address(yToken);
        }
    }

    function removeSupportedToken(address token) public onlyOwner returns (address) {
        YToken yToken = YToken(s_tokenToYToken[token]);
        s_supportedTokens.remove(token);
        delete s_tokenToYToken[token];
        emit SupportedToken(token, address(yToken), false);
        return address(yToken);
    }

    /*///////////////////////////////////////////////
                PUBLIC VIEW FUCTIONS
    ///////////////////////////////////////////////*/

    /// @notice Returns whether a bool whether the token is supported or not
    /// @param token The address of the token
    /// @return Is token supported or not
    function isSupportedToken(address token) public view returns (bool) {
        return s_supportedTokens.contains(token);
    }

    /// @notice Returns the address of the token's corresponding YToken contract
    /// @param token The address of the token
    /// @return The YToken contract address
    function getYTokenBasedOnToken(address token) public view returns (address) {
        return s_tokenToYToken[token];
    }

    function addTokenPriceFeed(address token, address priceFeed) public onlyOwner returns (address, address) {
        emit TokenPriceFeedAdded(token, priceFeed);
        return s_lpManager.addTokenPriceFeed(token, priceFeed);
    }

    function getNumberOfSupportedTokens() public view returns (uint256) {
        return s_supportedTokens.length();
    }

    function getSupportedTokenInArray(uint256 index) public view returns (address) {
        return s_supportedTokens.at(index);
    }

    // @question do we need this function???
    // receive() external payable {}
}
