// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.18;

interface TokenContract {
    function deposit() external;
    function withdraw() external;
    function transfer() external;
    function approve() external;
    function allowance() external;
}
