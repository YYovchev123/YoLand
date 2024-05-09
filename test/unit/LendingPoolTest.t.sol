// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {InterestRateModel} from "../../src/core/InterestRateModel.sol";
import {YToken} from "../../src/core/YToken.sol";
import {LendingPool} from "../../src/core/LendingPool.sol";
import {ERC20Mock} from "../mocks/UnderLyingAssetMock.sol";
import {Vault} from "../../src/core/Vault.sol";
import {Errors} from "../../src/libraries/Errors.sol";

contract LendingPoolTest is Test {
    LendingPool public lendingPool;
    InterestRateModel public interestRateModel;
    Vault public vault;

    ERC20Mock public WETH;
    ERC20Mock public DAI;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address[] public initialSupportedTokens;

    address owner = makeAddr("owner");
    address userOne = makeAddr("userOne");
    address userTwo = makeAddr("userTwo");

    function setUp() public {
        WETH = new ERC20Mock("Wrapped Ethereum", "WETH", 18);
        DAI = new ERC20Mock("DAI Token", "DAI", 18);
        initialSupportedTokens.push(address(WETH));
        initialSupportedTokens.push(address(DAI));

        vm.startPrank(owner);
        interestRateModel = new InterestRateModel(1);
        lendingPool = new LendingPool(address(interestRateModel), initialSupportedTokens);
        vault = new Vault(address(lendingPool));
        lendingPool.initializeVault(address(vault));
        vm.stopPrank();

        WETH.mint(userOne, 1_000e18);
        DAI.mint(userTwo, 10_000e18);

        // console.log("WETH address: ", address(WETH));
        // console.log("DAI address: ", address(DAI));
        // console.log("interestRateModel address: ", address(interestRateModel));
        // console.log("lendingPool address: ", address(lendingPool));
        // console.log("vault address: ", address(vault));
        // console.log("Owner: ", owner);
        // console.log("userOne: ", userOne);
        // console.log("userTwo: ", userTwo);
    }

    /// ======= Tests for setSupportedToken ======= ///
    function testSetSupportedTokenTrue() public {
        vm.prank(owner);
        address yToken = lendingPool.setSupporedToken(ETH, true);

        assert(lendingPool.isSupportedToken(ETH) == true);
        assert(yToken == lendingPool.getYTokenBasedOnToken(address(ETH)));
    }

    function testSetSupportedTokenFalse() public {
        vm.prank(owner);
        lendingPool.setSupporedToken(address(WETH), false);

        assert(lendingPool.isSupportedToken(address(WETH)) == false);
    }

    function testSetSupportedTokenRevertsIfTokenAlreadySupported() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.YTokenAlreadySupported.selector, address(WETH)));
        lendingPool.setSupporedToken(address(WETH), true);
    }

    function testSetSupportedTokenCanOnlyBeCalledByOwner() public {
        vm.prank(userOne);
        vm.expectRevert();
        lendingPool.setSupporedToken(ETH, true);
    }

    /// ======= Tests for deposit ======= ///
    function testDepositChangesBalancesAndMitsYTokens() public {
        uint256 amount = 100;
        vm.startPrank(userOne);
        WETH.approve(address(vault), type(uint256).max);
        lendingPool.deposit(address(WETH), amount);

        YToken wethYToken = YToken(lendingPool.getYTokenBasedOnToken(address(WETH)));

        uint256 expectedAmountYTokens = (amount * wethYToken.EXCHANGE_RATE_PRECISION()) / wethYToken.getExchangeRate();

        assert(vault.getBalance(userOne, address(WETH)) == amount);
        assert(wethYToken.balanceOf(userOne) == expectedAmountYTokens);
    }
}
