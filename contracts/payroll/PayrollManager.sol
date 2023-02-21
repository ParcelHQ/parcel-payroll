// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// Module Imports
import "../signature/Signature.sol";
import "../interfaces/AllowanceModule.sol";
import "./Storage.sol";

contract PayrollManager is ReentrancyGuardUpgradeable, Storage, Signature {
    // Payroll Functions

    using SafeERC20 for IERC20;

    /**
     * @dev Set usage status of a payout nonce
     * @param safeAddress  Address of the safe
     * @param payoutNonce Payout nonce to set
     */
    function packPayoutNonce(
        address safeAddress,
        uint256 payoutNonce
    ) internal {
        // Packed payout nonces are stored in an array of uint256
        // Each uint256 represents 256 payout nonces

        // Each payout nonce is packed into a uint256, so the index of the uint256 in the array is the payout nonce / 256
        uint256 slot = payoutNonce / 256;

        // The bit index of the uint256 is the payout nonce % 256 (0-255)
        uint256 bitIndex = payoutNonce % 256;

        // If the bit is set, the payout nonce has been used, if not, it has not been used
        if (slot >= orgs[safeAddress].packedPayoutNonces.length) {
            // If the slot is greater than the length of the array, we need to push new uint256s to the array
            // We need to push enough uint256s to the array so that the slot is the last index of the array
            while (orgs[safeAddress].packedPayoutNonces.length != slot) {
                orgs[safeAddress].packedPayoutNonces.push(0);
            }
        }

        // Set the bit to 1
        // This means that the payout nonce has been used
        orgs[safeAddress].packedPayoutNonces[slot] |= 1 << bitIndex;
    }

    /**
     * @dev Get usage status of a payout nonce
     * @param safeAddress  Address of the safe
     * @param payoutNonce Payout nonce to check
     * @return Boolean, true for used, false for unused
     */
    function getPayoutNonce(
        address safeAddress,
        uint256 payoutNonce
    ) internal view returns (bool) {
        // Each payout nonce is packed into a uint256, so the index of the uint256 in the array is the payout nonce / 256
        uint256 slotIndex = payoutNonce / 256;

        // The bit index of the uint256 is the payout nonce % 256 (0-255)
        uint256 bitIndex = payoutNonce % 256;

        //  If the slot is greater than the length of the array, the payout nonce has not been used
        if (
            orgs[safeAddress].packedPayoutNonces.length == 0 ||
            orgs[safeAddress].packedPayoutNonces.length <= slotIndex
        ) {
            return false;
        } else {
            // If the bit is set, the payout nonce has been used, if not, it has not been used
            return
                (orgs[safeAddress].packedPayoutNonces[slotIndex] &
                    (1 << bitIndex)) != 0;
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
        // check if safe is onboarded
        require(orgs[safeAddress].approverCount != 0, "CS009");

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

        // create a new array to store initial balances of  payment tokens
        uint256[] memory initialBalances = new uint256[](paymentTokens.length);

        for (uint256 i = 0; i < paymentTokens.length; i++) {
            if (paymentTokens[i] == address(0)) {
                initialBalances[i] = address(this).balance;
            } else {
                initialBalances[i] = IERC20(paymentTokens[i]).balanceOf(
                    address(this)
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
                (orgs[safeAddress].packedPayoutNonces.length == 0 ||
                    !getPayoutNonce(safeAddress, payoutNonce[i]))
            ) {
                // Transfer the funds to the recipient (to) addresses
                if (tokenAddress[i] == address(0)) {
                    packPayoutNonce(safeAddress, payoutNonce[i]);
                    // Transfer ether
                    (bool sent, bytes memory data) = to[i].call{
                        value: amount[i]
                    }("");

                    require(sent, "CS007");
                } else {
                    packPayoutNonce(safeAddress, payoutNonce[i]);
                    // Transfer ERC20 tokens
                    IERC20(tokenAddress[i]).safeTransfer(to[i], amount[i]);
                }
            }
        }

        // Check if the contract has any tokens left
        for (uint256 i = 0; i < paymentTokens.length; i++) {
            if (paymentTokens[i] == address(0)) {
                // Revert if the contract has any ether left
                require(address(this).balance == initialBalances[i], "CS018");
            } else if (
                IERC20(paymentTokens[i]).balanceOf(address(this)) !=
                initialBalances[i]
            ) {
                // Revert if the contract has any tokens left
                revert("CS018");
            }
        }
    }

    /**
     * @dev Receive Ether
     */
    receive() external payable {}

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
