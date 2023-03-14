// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "../interfaces/IAllowanceModule.sol";
import "../signature/Signature.sol";

contract PayrollManager is
    Signature,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @dev Set usage status of a payout nonce
     * @param payoutNonce Payout nonce to set
     */
    function packPayoutNonce(uint256 payoutNonce) internal {
        // Packed payout nonces are stored in an array of uint256
        // Each uint256 represents 256 payout nonces

        // Each payout nonce is packed into a uint256, so the index of the uint256 in the array is the payout nonce / 256
        uint256 slot = payoutNonce / 256;

        // The bit index of the uint256 is the payout nonce % 256 (0-255)
        uint256 bitIndex = payoutNonce % 256;

        // If the slot is greater than the length of the array, we need to add more slots
        if (packedPayoutNonces.length <= slot) {
            // Add the required number of slots

            while (packedPayoutNonces.length <= slot) {
                packedPayoutNonces.push(0);
            }
        }

        // Set the bit to 1
        // This means that the payout nonce has been used
        packedPayoutNonces[slot] |= 1 << bitIndex;
    }

    /**
     * @dev Get usage status of a payout nonce
     * @param payoutNonce Payout nonce to check
     * @return Boolean, true for used, false for unused
     */
    function getPayoutNonce(uint256 payoutNonce) public view returns (bool) {
        // Each payout nonce is packed into a uint256, so the index of the uint256 in the array is the payout nonce / 256
        uint256 slotIndex = payoutNonce / 256;

        // The bit index of the uint256 is the payout nonce % 256 (0-255)
        uint256 bitIndex = payoutNonce % 256;

        //  If the slot is greater than the length of the array, the payout nonce has not been used
        if (packedPayoutNonces.length <= slotIndex) {
            return false;
        } else {
            // If the bit is set, the payout nonce has been used, if not, it has not been used
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
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encode(owner(), to, tokenAddress, amount, payoutNonce)
            );
    }

    /**
     * @dev This function validates the signature and verifies if signatures are unique and the approver belongs to safe
     * @param roots Address of the token to send
     * @param signatures Amount of tokens to send
     */
    function validateSignatures(
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
                signer != SENTINEL_APPROVER &&
                    approvers[signer] != address(0) &&
                    signer > currentApprover,
                "CS014"
            );
            // Set the current approver to the signer
            currentApprover = signer;
        }
    }

    /**
     * @dev Validate the payroll transaction hashes and execute the payroll
     * @param to Addresses to send the funds to
     * @param tokenAddress Addresses of the tokens to send
     * @param amount Amounts of tokens to send
     * @param payoutNonce Payout nonces to use
     * @param proof Merkle proof of the payroll transaction hashes
     * @param roots Merkle roots of the payroll transaction hashes
     * @param signatures Signatures of the payroll transaction hashes
     * @param paymentTokens Addresses of all the tokens to send in the payroll
     * Note: The payment tokens should be in the ascending order and should not contain any duplicate tokens
     * @param payoutAmounts Total Amounts of respective tokens to send in the payroll
     */
    function executePayroll(
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

        validateSignatures(roots, signatures);

        // create a new array to store initial balances of  payment tokens
        uint256[] memory initialBalances = new uint256[](paymentTokens.length);

        for (uint256 i = 0; i < paymentTokens.length; i++) {
            if (paymentTokens[i] == address(0)) {
                initialBalances[i] = address(this).balance;
            } else {
                initialBalances[i] = IERC20Upgradeable(paymentTokens[i])
                    .balanceOf(address(this));
            }
        }

        {
            address currentToken;
            // Fetch the required tokens from the safe via Allowance module
            for (uint256 index = 0; index < paymentTokens.length; index++) {
                // Check if the token is already fetched
                require(paymentTokens[index] > currentToken, "CS002");
                execTransactionFromGnosis(
                    paymentTokens[index],
                    payoutAmounts[index]
                );
                currentToken = paymentTokens[index];
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
                if (
                    MerkleProofUpgradeable.verify(proof[i][j], roots[j], leaf)
                ) {
                    ++approvals;
                }
            }

            // Check if the approvals are greater than or equal to the required approvals
            if (approvals >= threshold && !getPayoutNonce(payoutNonce[i])) {
                // Transfer the funds to the recipient (to) addresses
                if (tokenAddress[i] == address(0)) {
                    packPayoutNonce(payoutNonce[i]);
                    // Transfer ether
                    (bool sent, bytes memory data) = to[i].call{
                        value: amount[i]
                    }("");

                    require(sent, "CS007");
                } else if (
                    IERC20Upgradeable(paymentTokens[i]).balanceOf(
                        address(this)
                    ) > initialBalances[i]
                ) {
                    // Revert if the contract has any tokens left
                    revert("CS018");
                }
            }
        }

        // Check if the contract has any tokens left
        for (uint256 i = 0; i < paymentTokens.length; i++) {
            if (paymentTokens[i] == address(0)) {
                // Revert if the contract has any ether left
                require(address(this).balance == initialBalances[i], "CS018");
            } else {
                require(
                    IERC20Upgradeable(paymentTokens[i]).balanceOf(
                        address(this)
                    ) == initialBalances[i],
                    "CS018"
                );
            }
        }
    }

    /**
     * @dev Receive Native tokens
     */
    receive() external payable {}

    /**
     * @dev Execute transaction from Gnosis Safe
     * @param tokenAddress Address of the token to send
     * @param amount Amount of tokens to send
     */
    function execTransactionFromGnosis(
        address tokenAddress,
        uint96 amount
    ) internal {
        // Execute payout via allowance module
        IAllowanceModule(ALLOWANCE_MODULE).executeAllowanceTransfer(
            owner(),
            tokenAddress,
            payable(address(this)),
            amount,
            address(0),
            0,
            address(this),
            bytes("")
        );
    }
}
