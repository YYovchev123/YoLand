// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {YToken} from "../../src/main/YToken.sol";
import {TokenContract} from "../mocks/UnderLyingAssetMock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract yTokenTest is Test {
    YToken yToken;
    TokenContract underlyingAsset;

    function setUp() public {
        underlyingAsset = new TokenContract("Wrapped Ether", "WETH", 18, 10_000e18);
        yToken = new YToken(address(this), address(underlyingAsset), "YToken", "YT");
    }
}
