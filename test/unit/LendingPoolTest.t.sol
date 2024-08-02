// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";

import {LendingPool} from "../../src/core/LendingPool.sol";
import {LPManager} from "../../src/core/LPManager.sol";
import {InterestRateModel} from "../../src/core/InterestRateModel.sol";
import {YToken} from "../../src/core/YToken.sol";

import {Errors} from "../../src/libraries/Errors.sol";
import {ERC20Mock} from "../mocks/UnderLyingAssetMock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract LendingPoolTestV2 is Test {
    ERC20Mock WETH;
    ERC20Mock DAI;
    ERC20Mock Token;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    MockV3Aggregator wethPrice;
    MockV3Aggregator daiPrice;
    MockV3Aggregator ethPrice;

    YToken wETHYToken;
    YToken daiYToken;
    YToken ethYToken;

    LendingPool lendingPool;
    LPManager lpManager;
    InterestRateModel interestRateModel;

    address deployer = makeAddr("deployer");
    address lenderOne = makeAddr("lenderOne");
    address lenderTwo = makeAddr("lenderTwo");
    address borrowerOne = makeAddr("borrowerOne");
    address borrowerTwo = makeAddr("borrowerTwo");

    address liquidator = makeAddr("liquidator");

    address[] public initialSupportedTokens;

    function setUp() public {
        WETH = new ERC20Mock("Wrapped Ethereum", "WETH", 18);
        DAI = new ERC20Mock("DAI Token", "DAI", 18);
        Token = new ERC20Mock("Token", "To", 18);

        wethPrice = new MockV3Aggregator(8, 2500);
        daiPrice = new MockV3Aggregator(8, 1);
        ethPrice = new MockV3Aggregator(8, 3000);

        initialSupportedTokens.push(address(WETH));
        initialSupportedTokens.push(address(DAI));

        vm.startPrank(deployer);
        interestRateModel = new InterestRateModel(1);
        lendingPool = new LendingPool(
            address(interestRateModel),
            initialSupportedTokens
        );
        lpManager = new LPManager(address(lendingPool));
        lendingPool.initializesLPManager(address(lpManager));
        vm.stopPrank();

        vm.prank(deployer);
        lendingPool.addSupportedToken(ETH);
        ethYToken = YToken(lendingPool.getYTokenBasedOnToken(ETH));

        vm.startPrank(deployer);
        lendingPool.addTokenPriceFeed(address(WETH), address(wethPrice));
        lendingPool.addTokenPriceFeed(ETH, address(ethPrice));
        lendingPool.addTokenPriceFeed(address(DAI), address(daiPrice));
        vm.stopPrank();

        WETH.mint(lenderOne, 1_000e18);
        WETH.mint(lenderTwo, 1_000e18);
        DAI.mint(lenderOne, 10_000e18);
        DAI.mint(lenderTwo, 10_000e18);

        WETH.mint(borrowerOne, 100e18);
        DAI.mint(borrowerTwo, 1_000e18);

        wETHYToken = YToken(lendingPool.getYTokenBasedOnToken(address(WETH)));
        daiYToken = YToken(lendingPool.getYTokenBasedOnToken(address(DAI)));
    }

    /// ======= Tests for addSupportedToken ======= ///
    function testAddSupportedTokenTrue() public {
        vm.prank(deployer);
        address yToken = lendingPool.addSupportedToken(address(Token));

        assert(lendingPool.isSupportedToken(address(Token)) == true);
        assert(yToken == lendingPool.getYTokenBasedOnToken(address(Token)));
    }

    function testAddSupportedTokenRevertsIfTokenAlreadySupported() public {
        vm.prank(deployer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.YTokenAlreadySupported.selector,
                address(WETH)
            )
        );
        lendingPool.addSupportedToken(address(WETH));
    }

    function testAddSupportedTokenCanOnlyBeCalledByOwner() public {
        vm.prank(lenderOne);
        vm.expectRevert();
        lendingPool.addSupportedToken(ETH);
    }

    /// ======= Tests for removeSupportedToken ======= ///
    function testRemoveSupportedTokenRemovesTokenFromArray() public {
        vm.prank(deployer);
        lendingPool.removeSupportedToken(address(WETH));

        assert(lendingPool.getYTokenBasedOnToken(address(WETH)) == address(0));
    }

    function testRemoveSupportedTokenFalse() public {
        assert(lendingPool.isSupportedToken(address(WETH)) == true);

        vm.prank(deployer);
        lendingPool.removeSupportedToken(address(WETH));

        assert(lendingPool.isSupportedToken(address(WETH)) == false);
    }

    function testRemoveSupportedTokenRevertsIfTokenAlreadyRemovedOrNotSupported()
        public
    {
        vm.prank(deployer);
        vm.expectRevert(Errors.TokenNotSupported.selector);
        lendingPool.removeSupportedToken(address(Token));
    }

    /// ======= Tests for lending ======= ///
    function testLendRevertIfAmountIsZero() public {
        vm.prank(lenderOne);
        vm.expectRevert(Errors.AmountCannotBeZero.selector);
        lendingPool.lend(address(WETH), 0);
    }

    function testLendRevertsIfTokenNotSupported() public {
        vm.prank(lenderOne);
        vm.expectRevert(Errors.TokenNotSupported.selector);
        lendingPool.lend(address(Token), 10);
    }

    function testLendRevertsIfTokenEthAndMsgValueZero() public {
        vm.deal(lenderOne, 100e18);
        vm.prank(lenderOne);
        vm.expectRevert(Errors.ValueSendWithNonETHToken.selector);
        lendingPool.lend{value: 10}(address(WETH), 10);
    }

    function testLendUpdatesUserAndContractBalanceAndMappingWETH() public {
        uint256 amount = 10e18;
        vm.startPrank(lenderOne);
        WETH.approve(address(lpManager), type(uint256).max);
        lendingPool.lend(address(WETH), amount);
        vm.stopPrank();

        uint256 expectedYTokenAmount = (amount *
            wETHYToken.EXCHANGE_RATE_PRECISION()) /
            wETHYToken.getExchangeRate();

        assert(lpManager.getTotalLendBalance(address(WETH)) == amount);
        assert(expectedYTokenAmount == wETHYToken.balanceOf(lenderOne));
        assert(WETH.balanceOf(address(lpManager)) == amount);
        assert(
            lpManager.getAccountLentBalance(lenderOne, address(WETH)) == amount
        );
    }

    function testLendUpdatesUserAndContractBalanceAndMappingTwiceWETH() public {
        uint256 amountOne = 10e18;
        uint256 amountTwo = 100e18;
        uint256 combinedAmount = amountOne + amountTwo;
        vm.startPrank(lenderOne);
        WETH.approve(address(lpManager), type(uint256).max);
        lendingPool.lend(address(WETH), amountOne);
        lendingPool.lend(address(WETH), amountTwo);
        vm.stopPrank();

        uint256 expectedYTokenAmount = (combinedAmount *
            wETHYToken.EXCHANGE_RATE_PRECISION()) /
            wETHYToken.getExchangeRate();
        assert(lpManager.getTotalLendBalance(address(WETH)) == combinedAmount);
        assert(expectedYTokenAmount == wETHYToken.balanceOf(lenderOne));
        assert(WETH.balanceOf(address(lpManager)) == combinedAmount);
        assert(
            lpManager.getAccountLentBalance(lenderOne, address(WETH)) ==
                combinedAmount
        );
    }

    function testLendUpdatesUserAndContractBalanceAndMappingETH() public {
        uint256 amount = 10e18;
        vm.deal(lenderOne, amount);
        vm.startPrank(lenderOne);
        lendingPool.lend{value: amount}(ETH, amount);
        vm.stopPrank();

        uint256 expectedYTokenAmount = (amount *
            wETHYToken.EXCHANGE_RATE_PRECISION()) /
            wETHYToken.getExchangeRate();
        assert(lpManager.getTotalLendBalance(ETH) == amount);
        assert(expectedYTokenAmount == ethYToken.balanceOf(lenderOne));
        assert(address(lpManager).balance == amount);
        assert(lpManager.getAccountLentBalance(lenderOne, ETH) == amount);
    }

    function testLendAndCheckLentValueInUsd() public {
        uint256 amountOne = 10e18;
        uint256 amountTwo = 100e18;
        // uint256 combinedAmount = amountOne + amountTwo;
        vm.startPrank(lenderOne);
        WETH.approve(address(lpManager), type(uint256).max);
        lendingPool.lend(address(WETH), amountOne);
        DAI.approve(address(lpManager), type(uint256).max);
        lendingPool.lend(address(DAI), amountTwo);
        vm.stopPrank();

        uint256 expectedLentValueInUsd = lpManager.getUsdValue(
            address(WETH),
            amountOne
        ) + lpManager.getUsdValue(address(DAI), amountTwo);
        uint256 actualLentValueInUsd = lpManager
            .getAccountTotalLentBalanceInUsd(lenderOne);

        assert(expectedLentValueInUsd == actualLentValueInUsd);
        assert(lpManager.getTotalLendBalance(address(WETH)) == amountOne);
        assert(lpManager.getTotalLendBalance(address(DAI)) == amountTwo);
    }

    /// ======= Tests for withdrawing ======= ///

    modifier lenderOneLendWethAndDai() {
        uint256 amount = 100e18;
        // uint256 combinedAmount = amountOne + amountTwo;
        vm.startPrank(lenderOne);
        WETH.approve(address(lpManager), type(uint256).max);
        lendingPool.lend(address(WETH), amount);
        DAI.approve(address(lpManager), type(uint256).max);
        lendingPool.lend(address(DAI), amount);
        vm.stopPrank();
        _;
    }

    function testWithdrawRevertsOnZeroAmount() public {
        vm.prank(lenderOne);
        vm.expectRevert(Errors.AmountCannotBeZero.selector);
        lendingPool.withdraw(address(WETH), 0);
    }

    function testWithdrawRevertsOnNotSupportedToken() public {
        vm.prank(lenderOne);
        vm.expectRevert(Errors.TokenNotSupported.selector);
        lendingPool.withdraw(address(Token), 10);
    }

    function testWithdrawUpdatesUserAndContractBalanceAndMapping()
        public
        lenderOneLendWethAndDai
    {
        uint256 amount = 100e18;
        uint256 lenderOneYTokenBalanceBefore = wETHYToken.balanceOf(lenderOne);
        uint256 lpWETHBalanceBefore = WETH.balanceOf(address(lpManager));
        uint256 lenderOneLentBalanceBefore = lpManager.getAccountLentBalance(
            lenderOne,
            address(WETH)
        );
        uint256 lenderOneWETHBalanceBefore = WETH.balanceOf(lenderOne);
        uint256 totalWETHLentBefore = lpManager.getTotalLendBalance(
            address(WETH)
        );
        vm.prank(lenderOne);
        lendingPool.withdraw(address(WETH), amount);
        uint256 lenderOneYTokenBalanceAfter = wETHYToken.balanceOf(lenderOne);
        uint256 lpWETHBalanceAfter = WETH.balanceOf(address(lpManager));
        uint256 lenderOneLentBalanceAfter = lpManager.getAccountLentBalance(
            lenderOne,
            address(WETH)
        );
        uint256 lenderOneWETHBalanceAfter = WETH.balanceOf(lenderOne);
        uint256 totalWETHLentAfter = lpManager.getTotalLendBalance(
            address(WETH)
        );
        uint256 expectedWETHBalanceOfLenderOneAfter = (amount *
            wETHYToken.getExchangeRate()) /
            wETHYToken.EXCHANGE_RATE_PRECISION();

        assert(
            lenderOneYTokenBalanceBefore - amount == lenderOneYTokenBalanceAfter
        );
        assert(lpWETHBalanceBefore - amount == lpWETHBalanceAfter);
        assert(
            lenderOneLentBalanceBefore - amount == lenderOneLentBalanceAfter
        );
        assert(
            expectedWETHBalanceOfLenderOneAfter ==
                lenderOneWETHBalanceAfter - lenderOneWETHBalanceBefore
        );
        assert(totalWETHLentBefore - amount == totalWETHLentAfter);
    }

    /// ======= Tests for depsitCollateral ======= ///
    function testDepositCollateralRevertIfAmountIsZero() public {
        vm.prank(borrowerOne);
        vm.expectRevert(Errors.AmountCannotBeZero.selector);
        lendingPool.depositCollateral(address(WETH), 0);
    }

    function testDepositCollateralRevertsIfTokenNotSupported() public {
        vm.prank(borrowerOne);
        vm.expectRevert(Errors.TokenNotSupported.selector);
        lendingPool.depositCollateral(address(Token), 10);
    }

    function testDepositCollateralRevertsIfEthAmountSentDoesNotMatchAmountParam()
        public
    {
        uint256 amount = 10e18;
        vm.deal(borrowerOne, amount);
        vm.startPrank(borrowerOne);
        vm.expectRevert(Errors.AmountAndValueSentDoNotMatch.selector);
        lendingPool.depositCollateral{value: amount}(ETH, amount + 1);
        vm.stopPrank();
    }

    function testDepositCollateralUpdatesUserAndContractBalanceAndMappingWETH()
        public
    {
        uint256 amount = 10e18;
        vm.startPrank(borrowerOne);
        WETH.approve(address(lpManager), type(uint256).max);
        lendingPool.depositCollateral(address(WETH), amount);
        vm.stopPrank();

        assert(WETH.balanceOf(address(lpManager)) == amount);
        assert(
            lpManager.getAccountBalanceCollateral(borrowerOne, address(WETH)) ==
                amount
        );
        assert(lpManager.getTotalCollateralBalance(address(WETH)) == amount);
    }

    function testDepositCollateralUpdatesUserAndContractBalanceAndMappingETH()
        public
    {
        uint256 amount = 10e18;
        vm.deal(borrowerOne, amount);
        vm.startPrank(borrowerOne);
        lendingPool.depositCollateral{value: amount}(ETH, amount);
        vm.stopPrank();

        assert(address(lpManager).balance == amount);
        assert(
            lpManager.getAccountBalanceCollateral(borrowerOne, ETH) == amount
        );
        assert(lpManager.getTotalCollateralBalance(ETH) == amount);
    }

    /// ======= Tests for borrow ======= ///
    modifier depositCollateralBorrowerOne() {
        uint256 amount = 10e18;
        vm.startPrank(borrowerOne);
        WETH.approve(address(lpManager), type(uint256).max);
        lendingPool.depositCollateral(address(WETH), amount);
        vm.stopPrank();
        _;
    }

    modifier depositCollateralBorrowerOneTwice() {
        uint256 amount = 10e18;
        vm.startPrank(borrowerOne);
        WETH.approve(address(lpManager), type(uint256).max);
        lendingPool.depositCollateral(address(WETH), amount);
        DAI.approve(address(lpManager), type(uint256).max);
        lendingPool.depositCollateral(address(WETH), amount);
        vm.stopPrank();
        _;
    }

    function testBorrowRevertsIfAmountZero() public {
        vm.prank(borrowerOne);
        vm.expectRevert(Errors.AmountCannotBeZero.selector);
        lendingPool.borrow(address(WETH), 0);
    }

    function testBorrowRevertsIfTokenNotSupported() public {
        vm.prank(borrowerOne);
        vm.expectRevert(Errors.TokenNotSupported.selector);
        lendingPool.borrow(address(Token), 10);
    }

    function testBorrowUpdatesBalancesAndMappings()
        public
        depositCollateralBorrowerOne
    {}
}
