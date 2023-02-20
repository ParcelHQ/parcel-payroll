// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// Module Imports
import "../signature/Signature.sol";
import "../interfaces/AllowanceModule.sol";
import "./Storage.sol";

contract PayrollManager is ReentrancyGuardUpgradeable, Storage, Signature, Pausable {
    // Payroll Functions

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
     * @dev Encode the transaction data for the payroll payout
     * @param to Address to send the funds to
     * @param tokenAddress Address of the token to send
     * @param amount Amount of tokens to send
     * @param payoutNonce Payout nonce to use
     * @return encodedHash Encoded hash of the transaction data
     */
    function encodeTransactionData(
        address to,
        address tokenAddress,
        uint256 amount,
        uint64 payoutNonce
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(to, tokenAddress, amount, payoutNonce));
    }

    /**
     * @dev This function validates the signature and verifies if signatures are unique and the approver belongs to safe
     * @param safeAddress Address to send the funds to
     * @param roots Address of the token to send
     * @param signatures Amount of tokens to send
     */
    function validateSignatures(
        address safeAddress,
        bytes32[] memory roots,
        bytes[] memory signatures
    ) internal view {
        // Validate the roots via approver signatures
        address currentApprover;
        for (uint256 i = 0; i < roots.length; i++) {
            // Recover signer from the signature
            address signer = validatePayrollTxHashes(roots[i], signatures[i]);
            // Check if the signer is an approver & is different from the current approver
            require(
                signer != SENTINEL_ADDRESS &&
                    orgs[safeAddress].approvers[signer] != address(0) &&
                    signer > currentApprover,
                "CS014"
            );
            // Set the current approver to the signer
            currentApprover = signer;
        }
    }

    /**
     * @dev Validate the payroll transaction hashes and execute the payroll
     * @param safeAddress Address of the safe
     * @param to Addresses to send the funds to
     * @param tokenAddress Addresses of the tokens to send
     * @param amount Amounts of tokens to send
     * @param payoutNonce Payout nonces to use
     * @param proof Merkle proof of the payroll transaction hashes
     * @param roots Merkle roots of the payroll transaction hashes
     * @param signatures Signatures of the payroll transaction hashes
     * @param paymentTokens Addresses of all the tokens to send in the payroll
     * @param payoutAmounts Total Amounts of respective tokens to send in the payroll
     */
    function executePayroll(
        address safeAddress,
        address[] memory to,
        address[] memory tokenAddress,
        uint128[] memory amount,
        uint64[] memory payoutNonce,
        bytes32[][][] memory proof,
        bytes32[] memory roots,
        bytes[] memory signatures,
        address[] memory paymentTokens,
        uint96[] memory payoutAmounts
    ) external nonReentrant whenNotPaused {
        // Validate the Input Data
        require(to.length == tokenAddress.length, "CS004");
        require(to.length == amount.length, "CS004");
        require(to.length == payoutNonce.length, "CS004");
        require(roots.length == signatures.length, "CS004");
        require(paymentTokens.length == payoutAmounts.length, "CS004");

        validateSignatures(safeAddress, roots, signatures);

        {
            // Fetch the required tokens from the safe via Allowance module
            for (uint256 index = 0; index < paymentTokens.length; index++) {
                execTransactionFromGnosis(
                    safeAddress,
                    paymentTokens[index],
                    payoutAmounts[index]
                );
            }
        }

        // Loop through the payouts
        for (uint256 i = 0; i < to.length; i++) {
            // Generate the leaf from the payout data
            bytes32 leaf = encodeTransactionData(
                to[i],
                tokenAddress[i],
                amount[i],
                payoutNonce[i]
            );

            // Initialize the approvals counter
            uint256 approvals;

            // Loop through the roots
            for (uint256 j = 0; j < roots.length; j++) {
                // Verify the root has been validated
                // Verify the proof against the current root and increment the approvals counter
                if (MerkleProof.verify(proof[i][j], roots[j], leaf)) {
                    ++approvals;
                }
            }

            // Check if the approvals are greater than or equal to the required approvals
            if (
                approvals >= orgs[safeAddress].approvalsRequired &&
                (packedPayoutNonces.length == 0 ||
                    !getPayoutNonce(payoutNonce[i]))
            ) {
                // Transfer the funds to the recipient (to) addresses
                if (tokenAddress[i] == address(0)) {
                    // Transfer ether
                    payable(to[i]).transfer(amount[i]);
                    packPayoutNonce(true, payoutNonce[i]);
                } else {
                    // Transfer ERC20 tokens
                    IERC20(tokenAddress[i]).transfer(to[i], amount[i]);
                    packPayoutNonce(true, payoutNonce[i]);
                }
            }
        }

        // Check if the contract has any tokens left
        for (uint256 i = 0; i < paymentTokens.length; i++) {
            if (IERC20(paymentTokens[i]).balanceOf(address(this)) > 0) {
                // Revert if the contract has any tokens left
                revert("CS018");
            }
        }
    }

    /**
     * @dev Execute transaction from Gnosis Safe
     * @param safeAddress Address of the Gnosis Safe
     * @param tokenAddress Address of the token to send
     * @param amount Amount of tokens to send
     */
    function execTransactionFromGnosis(
        address safeAddress,
        address tokenAddress,
        uint96 amount
    ) internal {
        // Execute payout via allowance module
        AllowanceModule(ALLOWANCE_MODULE).executeAllowanceTransfer(
            safeAddress,
            tokenAddress,
            payable(address(this)),
            amount,
            0x0000000000000000000000000000000000000000,
            0,
            address(this),
            bytes("")
        );
    }
}
