// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {InterestRateModel} from "../../src/core/InterestRateModel.sol";
import {TokenContract} from "../../src/main/TokenContract.sol";
import {YToken} from "../../src/main/YToken.sol";
import {LendingPool} from "../../src/core/LendingPool.sol";

contract LendingPoolTest is Test {
    LendingPool public lendingPool;
    InterestRateModel public interestRateModel;

    function setUp() public {
        interestRateModel = new InterestRateModel(1);
        lendingPool = new LendingPool(address(interestRateModel));
    }
}
