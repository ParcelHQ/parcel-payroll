// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

contract Storage {
    string public constant VERSION = "0.0.1";
    address internal constant SENTINEL_APPROVER = address(0x1);
    address immutable ALLOWANCE_MODULE =
        address(0xCFbFaC74C26F8647cBDb8c5caf80BB5b32E43134);

    // approvers Linked list of approvers
    mapping(address => address) internal approvers;

    // approverCount Number of approvers in the org
    uint256 internal approverCount;

    // theshold Number of approvals required for a single payout
    uint256 internal threshold;

    /**
     Array of uint256, each uint256 represents 256 payout nonces
     * Each payout nonce is packed into a uint256, so the index of the uint256 in the array is the payout nonce / 256
     * The bit index of the uint256 is the payout nonce % 256
     * If the bit is set, the payout nonce has been used, if not, it has not been used
    **/
    uint256[] packedPayoutNonces;
}
