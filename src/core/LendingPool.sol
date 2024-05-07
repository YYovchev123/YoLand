// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {OracleLib} from "../libraries/OracleLib.sol";
// import {TokenContract} from "../main/TokenContract.sol";
import {InterestRateModel} from "../core/InterestRateModel.sol";
import {YToken} from "../main/YToken.sol";
import {Errors} from "../libraries/Errors.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Owned} from "@solmate/src/auth/Owned.sol";
import {Vault} from "./Vault.sol";

// TODO add natspec to LendingPool
contract LendingPool is Owned(msg.sender) {
    event Deposit(address user, uint256 amount);

    Vault public s_vault;

    mapping(address token => address yToken) public s_tokenToYToken;

    constructor(address vault) {
        s_vault = Vault(vault);
    }

    function deposit(address token, uint256 amount) external {
        YToken yToken = YToken(s_tokenToYToken[token]);

        // update the state / interestRate

        // mint
        yToken.mint(msg.sender, amount);

        // transfer the tokens
        s_vault.transferTokenToVault(token, msg.sender, amount);

        // emit event
        emit Deposit(msg.sender, amount);
    }

    function withdraw(address token, uint256 amount) external {}
}
