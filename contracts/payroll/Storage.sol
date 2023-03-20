// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

abstract contract Storage {
    string public constant VERSION = "0.0.1";
    address internal constant SENTINEL_APPROVER = address(0x1);
    address constant ALLOWANCE_MODULE =
        0xCFbFaC74C26F8647cBDb8c5caf80BB5b32E43134;

    // approvers Linked list of approvers
    mapping(address => address) internal approvers;

    // approverCount Number of approvers in the org
    uint128 internal approverCount;

    // theshold Number of approvals required for a single payout
    uint128 public threshold;

    /**
     * @dev The payout nonce is used to prevent replay attacks
     * Each payout nonce is packed into a bit in a uint256. The bit is set to 1 if the nonce has been used and 0 if not.
     * This way, 256 nonces are packed into a single uint256 and stored in the value of packedPayoutNonces mapping.
     * The key of the mapping is the slot number of the payout. Each slot can store 256 nonces.
     * By using mapping, we can access any nonce in constant time.
     **/
    mapping(uint256 => uint256) packedPayoutNonces;

    // Cached domain separator
    bytes32 _cachedDomainSeparator;
    // Cached chain ID
    uint256 immutable _cachedChainId = block.chainid;
    // Cached contract address
    address _cachedThis;

    // Storage Gaps to prevent upgrade errors
    uint256[48] __gap;
}
