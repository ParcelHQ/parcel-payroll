//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/// @title Storage for Organizer Contract

abstract contract Storage {
    /**
     * @dev Struct for ORG
     * @param approverCount Number of approvers in the org
     * @param approvalsRequired Number of approvals required for a single payout
     * @param approvers Linked list of approvers
     */
    struct ORG {
        uint128 approverCount;
        uint128 approvalsRequired;
        mapping(address => address) approvers;
    }

    // Address of the Allowance Module
    address ALLOWANCE_MODULE;

    //  Sentinels to use with linked lists
    address internal constant SENTINEL_ADDRESS = address(0x1);

    /**
     * @dev Storage for Organisations
     * Mapping of org's safe address to ORG struct
     */
    mapping(address => ORG) public orgs;

    /**
     * @dev Storage for packed payout nonces
     * Array of uint256, each uint256 represents 256 payout nonces
     * Each payout nonce is packed into a uint256, so the index of the uint256 in the array is the payout nonce / 256
     * The bit index of the uint256 is the payout nonce % 256
     * If the bit is set, the payout nonce has been used, if not, it has not been used
     */
    uint256[] packedPayoutNonces;
}
