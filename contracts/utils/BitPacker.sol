//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../payroll/Modifiers.sol";


abstract contract BitPacker is Modifiers {
    /**
     * @dev Set usage status of a payout nonce
     * @param flag Boolean to pack, true for used, false for unused
     * @param payoutNonce Payout nonce to set
     */
    function packPayoutNonce(bool flag, uint256 payoutNonce) internal {
        uint256 slot = payoutNonce / 256;
        uint256 bitIndex = payoutNonce % 256;

        if (slot >= packedPayoutNonces.length) {
            packedPayoutNonces.push(1);
        }

        if (flag) {
            packedPayoutNonces[slot] |= 1 << bitIndex;
        } else {
            packedPayoutNonces[slot] &= ~(1 << bitIndex);
        }
    }

    /**
     * @dev Get usage status of a payout nonce
     * @param payoutNonce Payout nonce to check
     * @return Boolean, true for used, false for unused
     */
    function getPayoutNonce(uint256 payoutNonce) internal view returns (bool) {
        uint256 slotIndex = payoutNonce / 256;
        uint256 bitIndex = payoutNonce % 256;
        if (
            packedPayoutNonces.length == 0 ||
            packedPayoutNonces.length < slotIndex
        ) {
            return false;
        } else {
            return (packedPayoutNonces[slotIndex] & (1 << bitIndex)) != 0;
        }
    }


    

    /**
     * @dev Pack a boolean into a uint256 at a specific slot
     * @param fullInt The uint256 to pack the boolean into
     * @param slot The slot to pack the boolean into
     * @param flag The boolean to pack
     * @return The packed uint256
    */
    function packBooltoUint(uint256 fullInt, uint256 slot, bool flag) internal pure returns (uint256) {
        if (flag) {
            fullInt |= 1 << slot;
        } else {
            fullInt &= ~(1 << slot);
        }
        return fullInt;
    }

    /**
     * @dev Unpack a boolean from a uint256 at a specific slot
     * @param fullInt The uint256 to unpack the boolean from
     * @param slot The slot to unpack the boolean from
     * @return The unpacked boolean
    */
    function unpackBoolfromUint(uint256 fullInt, uint256 slot) internal pure returns (bool) {
        return (fullInt & (1 << slot)) != 0;
    }
}