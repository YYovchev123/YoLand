// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

library EthAddressLib {
    /**
     * @dev returns the address used within the protocol to identify ETH
     * @return the address assigned to ETH
     */
    function ethAddress() internal pure returns (address) {
        return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }
}
