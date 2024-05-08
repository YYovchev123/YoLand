// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Errors} from "../libraries/Errors.sol";

/// @title YToken
/// @author YovchevYoan
/// @notice This contract is a token that represents the shares owned by each user for a specified underlying token
/// @dev Responsible for updating the exchangeRate between underlying and yToken
contract YToken is ERC20 {
    using SafeERC20 for IERC20;

    /*///////////////////////////////////////////////
                    STATE VARIABLES
    ///////////////////////////////////////////////*/

    /// @notice The underLying token of the yToken
    IERC20 private immutable i_underlyingAsset;

    // @audit CHECK IF LENDINGPLATFORM IS THE RIGHT CONTRACT!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    /// @notice The address of the Lending Platform
    address private immutable i_lendingPool;

    /// @notice The underlying per asset exchange rate
    /// @dev ie: s_exchangeRate = 2
    /// @dev means 1 asset token is worth 2 underlying tokens
    uint256 private s_exchangeRate;

    /// @notice The exchange rate precision
    /// @dev It is used to calculate decimals precision
    uint256 public constant EXCHANGE_RATE_PRECISION = 1e18;

    /// @notice The starting exchange rate of yToken
    uint256 private constant STARTING_EXCHANGE_RATE = 1e18;

    /*///////////////////////////////////////////////
                        EVENTS
    ///////////////////////////////////////////////*/

    /// @notice Emitted when exchange rate is upated
    /// @param newExchangeRate The new exchange rate
    event ExchangeRateUpdated(uint256 newExchangeRate);

    /*///////////////////////////////////////////////
                        MODIFIERS
    ///////////////////////////////////////////////*/

    /// @notice Allows a function to be called only by the LendingPool
    modifier onlyLendingPool() {
        if (msg.sender != i_lendingPool) {
            revert Errors.onlyLendingPool();
        }
        _;
    }

    /// @notice Reverts if the address passed is equal to address(0)
    /// @param anAddress the address being checked
    modifier revertIfZeroAddress(address anAddress) {
        if (anAddress == address(0)) {
            revert Errors.ZeroAddress();
        }
        _;
    }

    /*///////////////////////////////////////////////
                    CONSTRUCTOR
    ///////////////////////////////////////////////*/

    /// @notice Constructor: sets the lendingPlaftorm, underlyingAsset, name and symbol
    /// @param lendingPool The address of the lendingPool
    /// @param underlyingAsset The underlying asset
    /// @param name The name of yToken
    /// @param symbol The symbol of yToken
    constructor(address lendingPool, address underlyingAsset, string memory name, string memory symbol)
        ERC20(name, symbol)
        revertIfZeroAddress(lendingPool)
        revertIfZeroAddress(underlyingAsset)
    {
        i_lendingPool = lendingPool;
        i_underlyingAsset = IERC20(underlyingAsset);
        s_exchangeRate = STARTING_EXCHANGE_RATE;
    }

    /*///////////////////////////////////////////////
                    EXTERNAL FUNCTIONS
    ///////////////////////////////////////////////*/

    /// @notice Mints a specified amount of tokens to a specified address
    /// @param to The address the tokens are minted to
    /// @param amount The amount of tokens to be minted
    function mint(address to, uint256 amount) external onlyLendingPool {
        _mint(to, amount);
    }

    /// @notice Burns a specified amount of tokens to a specified address
    /// @param account The address from whom the tokens are burned
    /// @param amount The amount of tokens to be burned
    function burn(address account, uint256 amount) external onlyLendingPool {
        _burn(account, amount);
    }

    // @audit Do I need this function??? Probably not!
    /// @notice Transfers a specified amount of underlying token to a specified address
    /// @param to The address to transfer to
    /// @param amount The amount of tokens to be transfered
    function transferUnderlyingTo(address to, uint256 amount) external onlyLendingPool {
        i_underlyingAsset.transfer(to, amount);
    }

    /// @notice Responsible for updating the exchange rate of AssetToken to Underlying
    /// @param fee The calcualted fee
    function updateExchangeRate(uint256 fee) external onlyLendingPool {
        /// @dev what if the totalSupply is 0?
        /// @dev what if this results in mishandling ETH!!! aka losing precision

        uint256 exchangeRate = s_exchangeRate;
        uint256 newExchangeRate = exchangeRate * (totalSupply() + fee) / totalSupply();

        if (newExchangeRate <= exchangeRate) {
            revert Errors.ExhangeRateCanOnlyIncrease(exchangeRate, newExchangeRate);
        }
        s_exchangeRate = newExchangeRate;
        emit ExchangeRateUpdated(exchangeRate);
    }

    /// @notice Returns the Exchange rate
    function getExchangeRate() external view returns (uint256) {
        return s_exchangeRate;
    }

    /// @notice Returns the address of the underlying token
    function getUnderlying() external view returns (address) {
        return address(i_underlyingAsset);
    }
}
