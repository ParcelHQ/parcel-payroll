// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/IAllowanceModule.sol";
import "../signature/Signature.sol";

// Errors
error InvalidPayoutSignature(bytes signature);
error PayrollDataLengthMismatch();
error RootSignatureLengthMismatch();
error PaymentTokenLengthMismatch();
error TokensLeftInContract(address tokenAddress);
error PayoutNonceAlreadyExecuted(uint64 nonce);
error TokensNotSorted(address tokenAddress1, address tokenAddress2);
error UnauthorizedTransfer();

contract PayrollManager is
    Signature,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Events
    event PayoutSuccessful(
        address tokenAddress,
        address to,
        uint256 amount,
        uint payoutNonce
    );
    event PayoutFailed(
        address tokenAddress,
        address to,
        uint256 amount,
        uint payoutNonce
    );

    /**
     * @dev Receive Native tokens
     */
    receive() external payable {}

    function safeTransferExternal(
        IERC20Upgradeable token,
        address to,
        uint256 amount
    ) external {
        if (msg.sender != address(this)) revert UnauthorizedTransfer();

        token.safeTransfer(to, amount);
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
     * @notice In a Batch of payouts, if one payout fails, the rest of the batch is continued after emitting the PayoutFailed event. In this case, the amount of the failed payout is left on the contract. The sweep function can be used to return the failed payout amount to the org safe in a separate transaction.
     */
    function executePayroll(
        address[] memory to,
        address[] memory tokenAddress,
        uint128[] memory amount,
        uint64[] memory payoutNonce,
        bytes32[][][] memory proof,
        bytes32[] memory roots,
        bytes[] memory signatures
    ) external nonReentrant whenNotPaused {
        // Validate the Input Data

        if (
            to.length == 0 ||
            to.length != tokenAddress.length ||
            to.length != amount.length ||
            to.length != payoutNonce.length
        ) revert PayrollDataLengthMismatch();

        if (roots.length != signatures.length)
            revert RootSignatureLengthMismatch();

        validateSignatures(roots, signatures);

        // Initialize the approvals array
        bool[] memory isApproved = new bool[](to.length);

        // Initialize the flag token address
        address tokenFlag = tokenAddress[0];

        // Initialize the flag token amount to fetch
        uint128 tokenFlagAmountToFetch = 0;

        // Loop through the payouts
        for (uint256 i = 0; i < to.length; i++) {
            // Revert if the payout nonce has already been executed
            if (getPayoutNonce(payoutNonce[i]))
                revert PayoutNonceAlreadyExecuted(payoutNonce[i]);

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
            for (
                uint256 j = 0;
                j < roots.length && approvals < threshold;
                j++
            ) {
                // Verify the root has been validated
                // Verify the proof against the current root and increment the approvals counter

                if (
                    MerkleProofUpgradeable.verify(proof[i][j], roots[j], leaf)
                ) {
                    ++approvals;
                }
            }

            // Check if the approvals are greater than or equal to the required approvals
            if (approvals >= threshold) {
                // Set the approval to true
                isApproved[i] = true;

                // Check if the token address is the same as the flag token address
                if (tokenFlag != tokenAddress[i]) {
                    // Enforce ascending order of token addresses
                    if (tokenFlag > tokenAddress[i])
                        revert TokensNotSorted(tokenFlag, tokenAddress[i]);

                    // Fetch the flag token from Gnosis
                    execTransactionFromGnosis(
                        tokenFlag,
                        uint96(tokenFlagAmountToFetch)
                    );
                    // Set the flag token address to the current token address
                    tokenFlag = tokenAddress[i];
                    // Reset the flag token amount to fetch
                    tokenFlagAmountToFetch = 0;
                }
                // Add the current payout amount to the flag token amount to fetch
                tokenFlagAmountToFetch += amount[i];
            }
        }
        if (tokenFlagAmountToFetch > 0) {
            // Fetch the flag token from Gnosis
            execTransactionFromGnosis(
                tokenFlag,
                uint96(tokenFlagAmountToFetch)
            );
        }

        // Loop through the approvals
        for (uint i = 0; i < isApproved.length; i++) {
            // Transfer the funds to the recipient (to) addresses
            if (isApproved[i] && !getPayoutNonce(payoutNonce[i])) {
                if (tokenAddress[i] == address(0)) {
                    // Transfer Native tokens
                    (bool sent, bytes memory data) = to[i].call{
                        value: amount[i]
                    }("");

                    if (!sent) {
                        emit PayoutFailed(
                            address(0),
                            to[i],
                            amount[i],
                            payoutNonce[i]
                        );
                    } else {
                        packPayoutNonce(payoutNonce[i]);
                        emit PayoutSuccessful(
                            address(0),
                            to[i],
                            amount[i],
                            payoutNonce[i]
                        );
                    }
                } else {
                    // Transfer ERC20 tokens
                    try
                        this.safeTransferExternal(
                            IERC20Upgradeable(tokenAddress[i]),
                            to[i],
                            amount[i]
                        )
                    {
                        packPayoutNonce(payoutNonce[i]);
                        emit PayoutSuccessful(
                            tokenAddress[i],
                            to[i],
                            amount[i],
                            payoutNonce[i]
                        );
                    } catch {
                        emit PayoutFailed(
                            tokenAddress[i],
                            to[i],
                            amount[i],
                            payoutNonce[i]
                        );
                    }
                }
            }
        }
    }

    /**
     * @dev Get usage status of a payout nonce
     * @param payoutNonce Payout nonce to check
     * @return Boolean, true for used, false for unused
     */
    function getPayoutNonce(uint256 payoutNonce) public view returns (bool) {
        // Each payout nonce is packed into a uint256, so the index of the uint256 in the array is the payout nonce / 256
        uint256 slotIndex = uint248(payoutNonce >> 8);

        // The bit index of the uint256 is the payout nonce % 256 (0-255)
        uint256 bitIndex = uint8(payoutNonce);

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
     * @dev Set usage status of a payout nonce
     * @param payoutNonce Payout nonce to set
     */
    function packPayoutNonce(uint256 payoutNonce) internal {
        // Packed payout nonces are stored in an array of uint256
        // Each uint256 represents 256 payout nonces

        // Each payout nonce is packed into a uint256, so the index of the uint256 in the array is the payout nonce / 256
        uint256 slot = uint248(payoutNonce >> 8);

        // The bit index of the uint256 is the payout nonce % 256 (0-255)
        uint256 bitIndex = uint8(payoutNonce);

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
            if (
                signer == SENTINEL_APPROVER ||
                approvers[signer] == address(0) ||
                signer <= currentApprover
            ) revert InvalidPayoutSignature(signatures[i]);

            // Set the current approver to the signer
            currentApprover = signer;
        }
    }

    /**
     * @dev Execute transaction from Gnosis Safe
     * @param tokenAddress Address of the token to send
     * @param amount Amount of tokens to send
     */
    function execTransactionFromGnosis(
        address tokenAddress,
        uint96 amount
    ) internal {
        uint contractBalance = 0;
        if (tokenAddress != address(0)) {
            contractBalance = IERC20Upgradeable(tokenAddress).balanceOf(
                address(this)
            );
        } else {
            contractBalance = address(this).balance;
        }

        // If the contract balance is greater than the amount, no need to fetch more tokens from safe
        if (contractBalance >= amount) return;

        // Execute payout via allowance module
        // Fetch amount is the difference between the flag token amount to fetch and the current token balance
        IAllowanceModule(ALLOWANCE_MODULE).executeAllowanceTransfer(
            owner(),
            tokenAddress,
            payable(address(this)),
            amount - uint96(contractBalance),
            address(0),
            0,
            address(this),
            bytes("")
        );
    }
}
