// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Module Imports
import "./Validators.sol";
import "../signature/Signature.sol";
import "../interfaces/index.sol";
import "./GnosisHelper.sol";
import "../utils/TransactionEncoder.sol";

contract PayrollManager is SignatureEIP712, GnosisHelper, TransactionEncoder {

    /**
     * @dev Validate the root hashes of payout data, save them and fetch the required tokens from the Gnosis Safe
     * @param safeAddress Address of the Org
     * @param roots Array of merkle roots to validate
     * @param signatures Array of signatures to validate
     * @param paymentTokens Array of payment tokens to fetch from Multisig
     * @param payoutAmounts Array of payout amounts to fetch from Multisig
     */
    function validatePayouts(
        address safeAddress,
        bytes32[] memory roots,
        bytes[] memory signatures,
        address[] memory paymentTokens,
        uint96[] memory payoutAmounts
    ) external onlyOnboarded(safeAddress) {
        require(roots.length == signatures.length, "CS004");
        require(paymentTokens.length == payoutAmounts.length, "CS004");

        bool isNewAdded;
        for (uint96 i = 0; i < roots.length; i++) {
            if (!approvedNodes[roots[i]]) {
                address signer = validatePayrollTxHashes(
                    roots[i],
                    signatures[i]
                );
                require(_isApprover(safeAddress, signer), "CS014");
                approvedNodes[roots[i]] = true;
                isNewAdded = true;
            }
        }

        if (isNewAdded) {
            {
                for (uint96 index = 0; index < paymentTokens.length; index++) {
                    execTransactionFromGnosis(
                        safeAddress,
                        paymentTokens[index],
                        payoutAmounts[index],
                        bytes("")
                    );
                }
            }
        }
    }

    /**
     * @dev Execute the payout
     * @param to Address to send the funds to
     * @param tokenAddress Address of the token to send
     * @param amount Amount of tokens to send
     * @param payoutNonce Payout nonce to use
     * @param safeAddress Address of the Org
     * @param proof Array of merkle proofs to validate
     * @param roots Array of merkle roots to validate
     */
    function executePayout(
        address payable to,
        address tokenAddress,
        uint256 amount,
        uint64 payoutNonce,
        address safeAddress,
        bytes32[][] memory proof,
        bytes32[] memory roots
    ) external onlyOnboarded(safeAddress) {
        require(roots.length == proof.length, "CS004");
        bytes32 leaf = encodeTransactionData(
            to,
            tokenAddress,
            amount,
            payoutNonce
        );

        if (packedPayoutNonces.length == 0 || !getPayoutNonce(payoutNonce)) {
            uint96 approvals;

            for (uint96 i = 0; i < roots.length; i++) {
                if (
                    MerkleProof.verify(proof[i], roots[i], leaf) &&
                    approvedNodes[roots[i]] == true
                ) {
                    approvals += 1;
                }
            }

            if (approvals >= orgs[safeAddress].approvalsRequired) {
                // Create Ether or IRC20 Transfer
                IERC20 erc20 = IERC20(tokenAddress);
                erc20.transfer(to, amount);
                packPayoutNonce(true, payoutNonce);
            }
        }
    }

    /**
     * @dev Validates and Executes a list of payouts in a single transaction
     * @param payouts Array of payouts to execute
     * @param safeAddress Address of the Org
     */
    function executePayouts(
        Payout[] calldata payouts,
        address safeAddress
    ) external onlyOnboarded(safeAddress) {

        require(payouts.length < 256, "Max 256 payouts per transaction");

        // List of token Addresses to fetch
        address[] memory uniqueTokenAddresses = new address[](payouts.length);
        uint8 uniqueTokenAddressesLength;

        // Approved payout indexes packed into a uint256
        uint256 approvedPayoutIndexes;
        // bool[] memory approvedPayouts = new bool[](payouts.length);

        // Loop through all payouts
        for (uint8 i = 0; i < payouts.length; i++) {
            // Validate input lengths to prevent out of bounds errors
            require(
                payouts[i].merkleProofs.length == payouts[i].merkleRoots.length && payouts[i].merkleRoots.length == payouts[i].rootSignatures.length,
                "CS004"
            );

            // If the payout nonce is already packed, revert the transaction
            if (packedPayoutNonces.length != 0 && getPayoutNonce(payouts[i].payoutNonce)) {
                revert("CS017");
            }
            
            // Initialize the number of approvals for the current payout
            uint8 approvals = 0;
            
            // Get the leaf hash for the current payout
            bytes32 leaf = encodeTransactionData(
                payouts[i].recipient,
                payouts[i].tokenAddress,
                payouts[i].amount,
                payouts[i].payoutNonce
            );
            
            // For each payout, loop through all roots 
            for (uint8 j = 0; j < payouts[i].merkleRoots.length; j++) {
                
                // For each root, check if it is a part of approvedRoots
                // If it is not, the mapping will return 0x00 (NULL_BYTES)
                if (approvedRoots[payouts[i].merkleRoots[j]] == NULL_BYTES) {
                    
                    // Validate the root against the signature
                    address signer = validatePayrollTxHashes(
                        payouts[i].merkleRoots[j],
                        payouts[i].rootSignatures[j]
                    );
                        // If the root is from a valid approver, add it to approvedRoots
                        if (_isApprover(safeAddress, signer)) { 
                            approvedRoots[payouts[i].merkleRoots[j]] = approvedRoots[SENTINEL_BYTES];
                            approvedRoots[SENTINEL_BYTES] = payouts[i].merkleRoots[j];
                        }
                        // Else, revert
                        else {
                            revert("CS014");
                        }
                }
                    // If it is part of approvedRoots, verify if current leaf is part of the root
                if (MerkleProof.verify(payouts[i].merkleProofs[j], payouts[i].merkleRoots[j], leaf)) {
                    // If it is, increment approval count
                    approvals += 1;
                    // If the token amount to be fetched is 0, it gets added in next step.
                    // So add the token to the uniqueTokenAddresses array
                    if (tokensToFetch[payouts[i].tokenAddress] == 0) {
                        uniqueTokenAddresses[uniqueTokenAddressesLength] = payouts[i].tokenAddress;
                        uniqueTokenAddressesLength += 1;
                    }

                    // Increment amount to be fetched from the allowance module
                    tokensToFetch[payouts[i].tokenAddress] += uint96(payouts[i].amount);
                } else {
                    // Else, revert
                    revert("CS016");
                }
            }

            // If approval count is greater than or equal to approvalsRequired, mark payout as approved
            if (approvals >= orgs[safeAddress].approvalsRequired) {
                // approvedPayouts[i] = true;
                approvedPayoutIndexes = packBooltoUint(approvedPayoutIndexes, i+1, true);
            }
        }

        // Fetch all tokens from the Safe
        fetchTokensFromOrg(uniqueTokenAddresses, safeAddress);
        
        // For each payout, if it is approved, execute it
        for (uint8 i = 0; i < payouts.length; i++) {
            if (unpackBoolfromUint(approvedPayoutIndexes, i+1)) {
                // Create Ether or IRC20 Transfer
                packPayoutNonce(true, payouts[i].payoutNonce);
                IERC20 erc20 = IERC20(payouts[i].tokenAddress);
                erc20.transfer(payouts[i].recipient, payouts[i].amount);
            }
        }

        // Clean up the approvedRoots linked list
        cleanUpApprovedRoots();
    }

    /**
     * @dev Fetches tokens from the Safe
     */
    function fetchTokensFromOrg(address[] memory uniqueTokenAddresses, address safeAddress) internal {
        // For each token address, fetch the tokens from the allowance module
        for (uint8 index = 0; index < uniqueTokenAddresses.length; index++) {
            // If the token address is 0x00, skip
            if(uniqueTokenAddresses[index] == address(0)) {
                continue;
            }
            // Fetch the tokens from the allowance module
            execTransactionFromGnosis(
                safeAddress,
                uniqueTokenAddresses[index],
                tokensToFetch[uniqueTokenAddresses[index]],
                bytes("")
            );
            // Delete the token from the tokensToFetch array
            delete tokensToFetch[uniqueTokenAddresses[index]];
        }
    }

    /**
     * @dev Clean up the approvedRoots linked list
     */
    function cleanUpApprovedRoots() internal {
        while (approvedRoots[SENTINEL_BYTES] != NULL_BYTES) {
            bytes32 root = approvedRoots[SENTINEL_BYTES];
            approvedRoots[SENTINEL_BYTES] = approvedRoots[root];
            delete approvedRoots[root];
        }
        
        approvedRoots[SENTINEL_BYTES] = SENTINEL_BYTES; 
    }
}