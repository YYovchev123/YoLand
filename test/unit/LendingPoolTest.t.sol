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

    TokenContract public WETH;
    TokenContract public DAI;

    YToken public yWETH;
    YToken public yDAI;

    address deployer = makeAddr("deployer");
    address userOne = makeAddr("userOne");
    address userTwo = makeAddr("userTwo");

    function setUp() public {
        vm.startPrank(deployer);
        interestRateModel = new InterestRateModel(1);
        lendingPool = new LendingPool(address(interestRateModel));

        WETH = new TokenContract("Wrapped Ethereum", "WETH", 18, 0);
        DAI = new TokenContract("DAI Token", "DAI", 18, 0);

        yWETH = new YToken(address(lendingPool), address(WETH), "YToken WETH", "yWETH");
        yDAI = new YToken(address(lendingPool), address(DAI), "YToken DAI", "yDAI");

        lendingPool.modifySupportedToken(address(WETH));
        lendingPool.modifySupportedToken(address(DAI));

        lendingPool.configureTokenToYToken(address(WETH), address(yWETH));
        lendingPool.configureTokenToYToken(address(DAI), address(yDAI));
    }

    // TODO Test all the functions in the LendingPool.sol
    function testIsSupportedToken() public {}
}
