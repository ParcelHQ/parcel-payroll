// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Module Imports
import "./Validators.sol";
import "../signature/Signature.sol";
import "../interfaces/index.sol";
import "./Modifiers.sol";

contract PayrollManager is SignatureEIP712, Validators, Modifiers {
    // Utility Functions

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
        bytes32 encodedHash = keccak256(
            abi.encode(to, tokenAddress, amount, payoutNonce)
        );
        return encodedHash;
    }

    function bulkExecution(
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
    ) external {
        require(to.length == tokenAddress.length, "Invalid Input");
        require(to.length == amount.length, "Invalid Input");
        require(to.length == payoutNonce.length, "Invalid Input");

        bool[] memory validatedRoots = new bool[](roots.length);
        {
            address currentApprover;
            for (uint256 i = 0; i < roots.length; i++) {
                address signer = validatePayrollTxHashes(
                    roots[i],
                    signatures[i]
                );
                require(
                    _isApprover(safeAddress, signer) &&
                        signer > currentApprover,
                    "Not an Operator"
                );
                currentApprover = signer;
                validatedRoots[i] = true;
            }
        }

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

        for (uint256 i = 0; i < to.length; i++) {
            bytes32 leaf = encodeTransactionData(
                to[i],
                tokenAddress[i],
                amount[i],
                payoutNonce[i]
            );

            uint96 approvals;

            for (uint96 j = 0; j < roots.length; j++) {
                if (
                    MerkleProof.verify(proof[i][j], roots[j], leaf) &&
                    validatedRoots[j] == true
                ) {
                    approvals += 1;
                }
            }

            if (
                approvals >= orgs[safeAddress].approvalsRequired &&
                (packedPayoutNonces.length == 0 ||
                    !getPayoutNonce(payoutNonce[i]))
            ) {
                // Create Ether or IRC20 Transfer
                IERC20 erc20 = IERC20(tokenAddress[i]);
                erc20.transfer(to[i], amount[i]);
                packPayoutNonce(true, payoutNonce[i]);
            }
        }

        for (uint256 i = 0; i < paymentTokens.length; i++) {
            IERC20 erc20 = IERC20(paymentTokens[i]);
            if (erc20.balanceOf(address(this)) > 0) {
                revert("");
            }
        }
    }

    /**
     * @dev Execute transaction from Gnosis Safe
     * @param safeAddress Address of the Gnosis Safe
     * @param tokenAddress Address of the token to send
     * @param amount Amount of tokens to send
     * @param signature Signature of the transaction
     */
    function execTransactionFromGnosis(
        address safeAddress,
        address tokenAddress,
        uint96 amount,
        bytes memory signature
    ) internal {
        AlowanceModule allowance = AlowanceModule(ALLOWANCE_MODULE);

        address payable to = payable(address(this));

        // Execute payout via allowance module
        allowance.executeAllowanceTransfer(
            GnosisSafe(safeAddress),
            tokenAddress,
            to,
            amount,
            0x0000000000000000000000000000000000000000,
            0,
            address(this),
            signature
        );
    }
}
