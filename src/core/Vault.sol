// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Errors} from "../libraries/Errors.sol";
import {EthAddressLib} from "../libraries/EthAddressLib.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// TODO add natscpec
contract Vault {
    using SafeERC20 for ERC20;

    address public s_lendingPool;

    mapping(address user => mapping(address token => uint256 amount)) balanceOf;

    constructor(address lendingPool) {
        s_lendingPool = lendingPool;
    }

    modifier onlyLendingPool() {
        if (msg.sender != s_lendingPool) revert Errors.onlyLendingPlatform();
        _;
    }

    function transferTokenToVault(address token, address user, uint256 amount) external payable onlyLendingPool {
        if (token != EthAddressLib.ethAddress()) {
            if (msg.value == 0) revert Errors.SendingETHWithERC20Transfer();

            balanceOf[user][token] += amount;
            ERC20(token).safeTransferFrom(user, address(this), amount);
        } else {
            if (msg.value != amount) revert Errors.AmountAndValueSentDoNotMatch();
            balanceOf[user][EthAddressLib.ethAddress()] += amount;
        }
    }
}
