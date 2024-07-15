// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";

import {LendingPool} from "../../src/core/LendingPool.sol";
import {LPManager} from "../../src/core/LPManager.sol";
import {InterestRateModel} from "../../src/core/InterestRateModel.sol";
import {YToken} from "../../src/core/YToken.sol";

import {Errors} from "../../src/libraries/Errors.sol";
import {ERC20Mock} from "../mocks/UnderLyingAssetMock.sol";

contract LendingPoolTestV2 is Test {
    ERC20Mock WETH;
    ERC20Mock DAI;
    ERC20Mock Token;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    LendingPool lendingPool;
    LPManager lpManger;
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

        initialSupportedTokens.push(address(WETH));
        initialSupportedTokens.push(address(DAI));

        vm.startPrank(deployer);
        interestRateModel = new InterestRateModel(1);
        lendingPool = new LendingPool(
            address(interestRateModel),
            initialSupportedTokens
        );
        lpManger = new LPManager(address(lendingPool));
        lendingPool.initializesLPManager(address(lpManger));
        vm.stopPrank();

        WETH.mint(lenderOne, 1_000e18);
        DAI.mint(lenderTwo, 10_000e18);

        WETH.mint(borrowerOne, 100e18);
        DAI.mint(borrowerTwo, 1_000e18);
    }

    /// ======= Tests for addSupportedToken ======= ///
    function testAddSupportedTokenTrue() public {
        vm.prank(deployer);
        address yToken = lendingPool.addSupportedToken(ETH);

        assert(lendingPool.isSupportedToken(ETH) == true);
        assert(yToken == lendingPool.getYTokenBasedOnToken(address(ETH)));
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
}
