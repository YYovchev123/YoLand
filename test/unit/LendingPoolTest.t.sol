// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {InterestRateModel} from "../../src/core/InterestRateModel.sol";
import {YToken} from "../../src/core/YToken.sol";
import {LendingPool} from "../../src/core/LendingPool.sol";
import {ERC20Mock} from "../mocks/UnderLyingAssetMock.sol";
import {Vault} from "../../src/core/Vault.sol";
import {CollateralTracker} from "../../src/core/CollateralTracker.sol";
import {Errors} from "../../src/libraries/Errors.sol";

contract LendingPoolTest is Test {
    LendingPool public lendingPool;
    InterestRateModel public interestRateModel;
    Vault public vault;
    CollateralTracker public collateralTracker;

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
        collateralTracker = new CollateralTracker(address(lendingPool));

        lendingPool.initializeVaultAndCollateralTracker(address(vault), address(collateralTracker));
        vm.stopPrank();

        WETH.mint(userOne, 1_000e18);
        DAI.mint(userTwo, 10_000e18);

        // console.log("WETH address: ", address(WETH));
        // console.log("DAI address: ", address(DAI));
        // console.log("interestRateModel address: ", address(interestRateModel));
        console.log("lendingPool address: ", address(lendingPool));
        console.log("vault address: ", address(vault));
        // console.log("Owner: ", owner);
        console.log("userOne: ", userOne);
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

    /// ======= Tests for lend ======= ///
    function testLendChangesBalancesAndMitsYTokens() public {
        uint256 amount = 100;
        vm.startPrank(userOne);
        WETH.approve(address(vault), type(uint256).max);
        lendingPool.lend(address(WETH), amount);

        YToken wethYToken = YToken(lendingPool.getYTokenBasedOnToken(address(WETH)));

        uint256 expectedAmountYTokens = (amount * wethYToken.EXCHANGE_RATE_PRECISION()) / wethYToken.getExchangeRate();

        assert(vault.getBalance(userOne, address(WETH)) == amount);
        assert(wethYToken.balanceOf(userOne) == expectedAmountYTokens);
    }

    function testLendRevertsIfTokenNotEthAndMsgValueIsNotZero() public {
        uint256 amount = 100;
        vm.deal(userOne, 10);
        vm.startPrank(userOne);
        WETH.approve(address(vault), type(uint256).max);
        vm.expectRevert(Errors.ValueSendWithNonETHToken.selector);
        lendingPool.lend{value: 10}(address(WETH), amount);
    }

    function testLendRevertsIfYTokenAmountIsZero() public {
        uint256 amount = 0;
        vm.startPrank(userOne);
        WETH.approve(address(vault), type(uint256).max);
        vm.expectRevert(Errors.AmountCannotBeZero.selector);
        lendingPool.lend(address(WETH), amount);
    }

    function testLendEthIncrementUserBalanceCorrectly() public {
        vm.prank(owner);
        lendingPool.setSupporedToken(ETH, true);

        uint256 amount = 100;
        vm.deal(userOne, amount);
        vm.startPrank(userOne);
        lendingPool.lend{value: amount}(ETH, amount);

        assert(vault.getBalance(userOne, ETH) == amount);
    }

    function testLendEthRevertIfAmountAndMsgValueAreNotEqual() public {
        vm.prank(owner);
        lendingPool.setSupporedToken(ETH, true);

        uint256 amount = 100;
        vm.deal(userOne, amount);
        vm.startPrank(userOne);
        vm.expectRevert(Errors.AmountAndValueSentDoNotMatch.selector);
        lendingPool.lend{value: amount}(ETH, 10);
    }

    function testLendRevertsIfTokenIsNotSupported() public {
        uint256 amount = 100;
        vm.deal(userOne, amount);
        vm.startPrank(userOne);
        vm.expectRevert(Errors.TokenNotSupported.selector);
        lendingPool.lend{value: amount}(ETH, 100);
    }

    function testLendRevertsIfAmountZeroIsPassed() public {
        uint256 amount = 0;
        vm.startPrank(userOne);
        WETH.approve(address(vault), type(uint256).max);
        vm.expectRevert(Errors.AmountCannotBeZero.selector);
        lendingPool.lend(address(WETH), amount);
    }

    function testLendDifferentTokensMintsDifferentYTokens() public {}

    /// ======= Tests for withdraw ======= ///

    modifier lendUserOne() {
        uint256 amount = 100;
        vm.startPrank(userOne);
        WETH.approve(address(vault), amount);
        lendingPool.lend(address(WETH), amount);
        vm.stopPrank();

        _;
    }

    function testWithdrawChangesYTokenAndTokenBalancesWETH() public lendUserOne {
        YToken wethYToken = YToken(lendingPool.getYTokenBasedOnToken(address(WETH)));
        uint256 amount = 100;

        uint256 userOneYTokenBalanceBefore = wethYToken.balanceOf(userOne);
        uint256 userOneWETHBalanceBefore = WETH.balanceOf(userOne);

        vm.prank(userOne);
        lendingPool.withdraw(address(WETH), amount);

        uint256 userOneYTokenBalanceAfter = wethYToken.balanceOf(userOne);

        uint256 expectedUserBalanceGain = (amount * wethYToken.getExchangeRate()) / wethYToken.EXCHANGE_RATE_PRECISION();

        assert(WETH.balanceOf(userOne) == userOneWETHBalanceBefore + expectedUserBalanceGain);
        assert(userOneYTokenBalanceBefore - amount == userOneYTokenBalanceAfter);
    }

    function testWithdrawChangesYTokenAndTokenBalancesETH() public {
        vm.prank(owner);
        lendingPool.setSupporedToken(ETH, true);

        uint256 amount = 100;
        vm.deal(userOne, amount);
        vm.startPrank(userOne);
        lendingPool.lend{value: amount}(ETH, amount);

        uint256 userOneBalanceAfterDeposit = userOne.balance;

        lendingPool.withdraw(ETH, amount);

        uint256 userOneBalanceAfterWithdrawal = userOne.balance;
        vm.stopPrank();

        assert(userOneBalanceAfterDeposit + userOneBalanceAfterWithdrawal == userOne.balance);
        assert(userOneBalanceAfterDeposit + userOneBalanceAfterWithdrawal == amount);
    }

    function testWithdrawRevertsOnAmountZero() public lendUserOne {
        uint256 amount = 0;
        vm.prank(userOne);
        vm.expectRevert(Errors.AmountCannotBeZero.selector);
        lendingPool.withdraw(address(WETH), amount);
    }

    function testWithdrawRevertsIfTokenNotSupported() public lendUserOne {
        uint256 amount = 100;
        vm.prank(userOne);
        vm.expectRevert(Errors.TokenNotSupported.selector);
        lendingPool.withdraw(ETH, amount);
    }
}
