// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TokenContract} from "../../src/main/TokenContract.sol";
import {Errors} from "../../src/libraries/Errors.sol";

contract TokenContractTest is Test {
    event Deposit(address indexed from, uint256 amount);
    event Withdraw(address indexed to, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    TokenContract public tokenContract;

    string public constant NAME = "TestToken";
    string public constant SYBMOL = "TT";
    uint8 public constant DECIMALS = 18;
    uint256 public constant INITIAL_SUPPLY = 1000e18;

    address userOne = makeAddr("userOne");
    address userTwo = makeAddr("userTwo");

    function setUp() public {
        tokenContract = new TokenContract(NAME, SYBMOL, DECIMALS, INITIAL_SUPPLY);
    }

    /*///////////////////////////////////////////////
                    CONSTRUCTOR TEST
    ///////////////////////////////////////////////*/

    function testConstructorInitialization() public view {
        assert(keccak256(abi.encodePacked(tokenContract.getName())) == keccak256(abi.encodePacked(NAME)));
        assert(keccak256(abi.encodePacked(tokenContract.getSymbol())) == keccak256(abi.encodePacked(SYBMOL)));
        assert(tokenContract.getTotalSupply() == INITIAL_SUPPLY);
        assert(tokenContract.getDecimals() == DECIMALS);
    }

    /*///////////////////////////////////////////////
                    DEPOSIT TEST
    ///////////////////////////////////////////////*/

    function testDepositChangesBalanceAndTotalAmount(uint256 amountToDeposit) public {
        amountToDeposit = bound(amountToDeposit, 1, type(uint256).max - tokenContract.getTotalSupply());

        vm.prank(userOne);
        tokenContract.deposit(amountToDeposit);

        assert(tokenContract.balanceOf(userOne) == amountToDeposit);
        assert(tokenContract.getTotalSupply() == amountToDeposit + INITIAL_SUPPLY);
    }

    function testDepositEmitsEvent() public {
        uint256 amountToDeposit = 100e18;
        vm.prank(userOne);
        vm.expectEmit();
        emit Deposit(userOne, amountToDeposit);
        tokenContract.deposit(amountToDeposit);
    }

    function testDepositRevertOnAmountZero() public {
        uint256 amountToDeposit = 0;
        vm.prank(userOne);
        vm.expectRevert(Errors.InsufficientDeposit.selector);
        tokenContract.deposit(amountToDeposit);
    }

    function testDepositsReturnsTrueOnSuccess() public {
        uint256 amountToDeposit = 100;
        vm.prank(userOne);
        bool result = tokenContract.deposit(amountToDeposit);

        assert(result == true);
    }
    // If there is a need for approval, test it!!!

    /*///////////////////////////////////////////////
                    WITHDRAW TEST
    ///////////////////////////////////////////////*/

    modifier deposit() {
        uint256 amountToDeposit = INITIAL_SUPPLY;
        vm.prank(userOne);
        tokenContract.deposit(amountToDeposit);
        console.log("User Balance: ", tokenContract.balanceOf(userOne));
        _;
    }

    function testWithdrawChangesBalanceAndTotalAmount(uint256 amountToWithdraw) public deposit {
        amountToWithdraw = bound(amountToWithdraw, 1, tokenContract.balanceOf(userOne));

        uint256 userBalanceBefore = tokenContract.balanceOf(userOne);
        uint256 totalBalanceBefore = tokenContract.getTotalSupply();

        vm.prank(userOne);
        tokenContract.withdraw(amountToWithdraw);

        assert(tokenContract.balanceOf(userOne) == userBalanceBefore - amountToWithdraw);
        assert(tokenContract.getTotalSupply() == totalBalanceBefore - amountToWithdraw);
    }

    function testWithdrawEmitsEvent() public deposit {
        uint256 amountToWithdraw = 100e18;
        vm.prank(userOne);
        vm.expectEmit();
        emit Withdraw(userOne, amountToWithdraw);
        tokenContract.withdraw(amountToWithdraw);
    }

    function testWithdrawReturnsTrueOnSuccess() public deposit {
        uint256 amountToWithdraw = 100;
        vm.prank(userOne);
        bool result = tokenContract.withdraw(amountToWithdraw);

        assert(result == true);
    }

    /*///////////////////////////////////////////////
                    TRANSFER TEST
    ///////////////////////////////////////////////*/

    function testTransferChangesBalances(uint256 amountToTransfer) public deposit {
        amountToTransfer = bound(amountToTransfer, 1, tokenContract.balanceOf(userOne));

        uint256 userOneBalanceBefore = tokenContract.balanceOf(userOne);
        uint256 userTwoBalanceBefore = tokenContract.balanceOf(userTwo);

        vm.prank(userOne);
        tokenContract.transfer(userTwo, amountToTransfer);

        assert(tokenContract.balanceOf(userOne) == userOneBalanceBefore - amountToTransfer);
        assert(tokenContract.balanceOf(userTwo) == userTwoBalanceBefore + amountToTransfer);
    }

    function testTransferRevertsIfAmountIsBiggerThanUserBalance() public deposit {
        vm.prank(userOne);
        vm.expectRevert(Errors.InsufficientBalance.selector);
        tokenContract.transfer(userTwo, 10000e18);
    }

    function testTransferEmitsEvent() public deposit {
        uint256 amount = 100e18;
        vm.prank(userOne);
        vm.expectEmit();
        emit Transfer(userOne, userTwo, amount);
        tokenContract.transfer(userTwo, amount);
    }

    function testTransferReturnsTrueOnSuccess() public deposit {
        uint256 amount = 100e18;

        vm.prank(userOne);
        bool success = tokenContract.transfer(userTwo, amount);

        assert(success == true);
    }

    /*///////////////////////////////////////////////
                    TRANSFERFROM TEST
    ///////////////////////////////////////////////*/

    modifier approve() {
        vm.prank(userOne);
        tokenContract.approve(userTwo, INITIAL_SUPPLY);
        _;
    }

    function testTransferFromChangesBalancesAndAllowance(uint256 amountToTransfer) public deposit approve {
        uint256 approvedAmount = tokenContract.allowance(userOne, userTwo);
        amountToTransfer = bound(amountToTransfer, 1, approvedAmount);

        uint256 userOneBalanceBefore = tokenContract.balanceOf(userOne);
        uint256 userTwoBalanceBefore = tokenContract.balanceOf(userTwo);

        vm.prank(userTwo);
        tokenContract.transferFrom(userOne, userTwo, amountToTransfer);

        assert(tokenContract.balanceOf(userOne) == userOneBalanceBefore - amountToTransfer);
        assert(tokenContract.balanceOf(userTwo) == userTwoBalanceBefore + amountToTransfer);
    }

    function testTransferFromEmitsEvent() public deposit approve {
        uint256 amountToTransfer = 100e18;
        vm.prank(userTwo);
        vm.expectEmit();
        emit Transfer(userOne, userTwo, amountToTransfer);
        tokenContract.transferFrom(userOne, userTwo, amountToTransfer);
    }

    function testTransferFromRevertsIfAmountNotAllowed() public deposit approve {
        uint256 amountToTransfer = 10000e18;
        vm.prank(userTwo);
        vm.expectRevert(Errors.InsufficientAllowance.selector);
        tokenContract.transferFrom(userOne, userTwo, amountToTransfer);
    }

    function testTransferFromReturnsTrueOnSuccess() public deposit approve {
        uint256 amountToTransfer = 100e18;
        vm.prank(userTwo);
        bool success = tokenContract.transferFrom(userOne, userTwo, amountToTransfer);

        assert(success == true);
    }

    /*///////////////////////////////////////////////
                    APPROVE TEST
    ///////////////////////////////////////////////*/

    function testApproveChangesAllowance(uint256 amountToApprove) public deposit {
        vm.prank(userOne);
        tokenContract.approve(userTwo, amountToApprove);

        uint256 approvedAmount = tokenContract.allowance(userOne, userTwo);

        assert(approvedAmount == amountToApprove);
    }

    function testApproveEmitsEvent() public deposit {
        uint256 amount = 100e18;
        vm.prank(userOne);
        vm.expectEmit();
        emit Approval(userOne, userTwo, amount);
        tokenContract.approve(userTwo, amount);
    }

    function testApproveReturnsTrueWhenSuccessful() public deposit {
        uint256 amount = 100e18;
        vm.prank(userOne);
        bool success = tokenContract.approve(userTwo, amount);

        assert(success == true);
    }
}
