//contracts/Organizer.sol
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Storage for Organizer Contract

abstract contract Storage {
  /**
   * @dev Struct for ORG
   * @param approverCount Number of approvers in the org
   * @param approvers Linked list of approvers
   * @param approvalsRequired Number of approvals required for a single payout
   * @param claimables Mapping of claimables
   * @param autoClaim Mapping of autoClaim
   */
  struct ORG {
    uint256 approverCount;
    mapping(address => address) approvers;
    // mapping(address => ApprovalLevel[]) approvalMatrices;
    uint256 approvalsRequired;
    mapping(address => mapping(address => uint96)) claimables;
    mapping(address => bool) autoClaim;
  }

  // Address of the Allowance Module
  address ALLOWANCE_MODULE;

  // Enum for Operation
  enum Operation {
    Call,
    DelegateCall
  }

  //  Sentinels to use with linked lists
  address internal constant SENTINEL_ADDRESS = address(0x1);
  address internal MASTER_OPERATOR;
  uint256 internal constant SENTINEL_UINT = 1;

  /**
   * @dev Storage for Organisations
   * Mapping of org's safe address to ORG struct
   */
  mapping(address => ORG) orgs;

  /**
   * @dev Storage for root nodes of approved payout merkle trees
   * Mapping of root node to boolean, true if approved, false if not
   */
  mapping(bytes32 => bool) approvedNodes;

  /**
   * @dev Storage for packed payout nonces
   * Array of uint256, each uint256 represents 256 payout nonces
   * Each payout nonce is packed into a uint256, so the index of the uint256 in the array is the payout nonce / 256
   * The bit index of the uint256 is the payout nonce % 256
   * If the bit is set, the payout nonce has been used, if not, it has not been used
   */
  uint256[] packedPayoutNonces;
}
