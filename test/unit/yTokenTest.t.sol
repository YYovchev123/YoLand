// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {YToken} from "../../src/main/YToken.sol";
import {TokenContract} from "../../src/main/TokenContract.sol";

contract yTokenTest is Test {
    YToken yToken;
    TokenContract tokenContract;

    function setUp() public {
        tokenContract = new TokenContract("TestToken", "TT", 18, 1000e18);
        yToken = new YToken(address(this), address(tokenContract), "YToken", "YT");
    }
}
