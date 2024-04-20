// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {InterestRateModel} from "../../src/core/InterestRateModel.sol";
import {Errors} from "../../src/libraries/Errors.sol";

contract InterestRateModelTest is Test {
    InterestRateModel interestRateModel;
    uint256 public constant BASE_INTEREST_RATE = 1;

    function setUp() public {
        interestRateModel = new InterestRateModel(BASE_INTEREST_RATE);
    }

    function testGetInterestRateCalculation() public view {
        uint256 utilizationRatio = 5;
        uint256 expectedResult = 6;

        assert(interestRateModel.getInterestRate(utilizationRatio) == expectedResult);
    }

    function testGetBaseInterestRateReturnsBaseInterestRate() public view {
        assert(interestRateModel.getBaseInterestRate() == BASE_INTEREST_RATE);
    }
}
