// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TokenContract} from "../src/main/TokenContract.sol";

contract TokenContractTest is Test {
    TokenContract public tokenContract;
    string public constant NAME = "TestToken";
    string public constant SYBMOL = "TT";
    uint8 public constant DECIMALS = 18;
    uint256 public constant INITIAL_SUPPLY = 1000e18;

    function setUp() public {
        tokenContract = new TokenContract(NAME, SYBMOL, DECIMALS, INITIAL_SUPPLY);
    }

    function testConstructorInitialization() public view {
        assertEq(keccak256(abi.encodePacked(tokenContract.getName)), keccak256(abi.encodePacked(NAME)));
        // assertEq(abi.encode(tokenContract.getSymbol), abi.encode(SYBMOL));
        // assertEq(abi.encode(tokenContract.getTotalSupply), abi.encode(INITIAL_SUPPLY));
        // assertEq(abi.encode(tokenContract.getDecimals), abi.encode(DECIMALS));
    }

    function testDepositChangesBalanceAndTotalAmount() public {}

    function testDepositEmitsEvent() public {}

    function testDepositRevertOnAmountZero() public {}
}
