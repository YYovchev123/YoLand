// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

/// @title EthAddressLib
/// @author YovchevYoan
/// @notice A library for fetching eth Address
/// @dev It includes function returning eth Address
library EthAddressLib {
    /**
     * @dev returns the address used within the protocol to identify ETH
     * @return the address assigned to ETH
     */
    function ethAddress() internal pure returns (address) {
        return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }
}
