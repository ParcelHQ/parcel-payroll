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

    /**
     * @dev Validate the root hashes of payout data, save them and fetch the required tokens from the Gnosis Safe
     * @param safeAddress Address of the Org
     * @param roots Array of merkle roots to validate
     * @param signatures Array of signatures to validate
     */
    function validatePayouts(
        address safeAddress,
        bytes32[] memory roots,
        bytes[] memory signatures
    ) external onlyOnboarded(safeAddress) {
        require(roots.length == signatures.length, "CS004");

        for (uint96 i = 0; i < roots.length; i++) {
            if (!approvedNodes[roots[i]]) {
                address signer = validatePayrollTxHashes(
                    roots[i],
                    signatures[i]
                );
                require(_isApprover(safeAddress, signer), "CS014");
                approvedNodes[roots[i]] = true;
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
                packPayoutNonce(true, payoutNonce);

                // Create Ether or IRC20 Transfer
                IERC20 erc20 = IERC20(tokenAddress);
                erc20.transfer(to, amount);
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

    /**
     * @dev Sends multiple transactions and reverts all if one fails.
     * @param transactions Encoded transactions. Each transaction is encoded as a packed bytes of
     *                     operation has to be uint8(0) in this version (=> 1 byte),
     *                     to as a address (=> 20 bytes),
     *                     value as a uint256 (=> 32 bytes),
     *                     data length as a uint256 (=> 32 bytes),
     *                     data as bytes.
     *                     see abi.encodePacked for more information on packed encoding
     * @notice The code is for most part the same as the normal MultiSend (to keep compatibility),
     *         but reverts if a transaction tries to use a delegatecall.
     * @notice This method is payable as delegatecalls keep the msg.value from the previous call
     *         If the calling method (e.g. execTransaction) received ETH this would revert otherwise
     */
    function multiSend(bytes memory transactions) public payable {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let length := mload(transactions)
            let i := 0x20
            for {
                // Pre block is not used in "while mode"
            } lt(i, length) {
                // Post block is not used in "while mode"
            } {
                // First byte of the data is the operation.
                // We shift by 248 bits (256 - 8 [operation byte]) it right since mload will always load 32 bytes (a word).
                // This will also zero out unused data.
                let operation := shr(0xf8, mload(add(transactions, i)))
                // We offset the load address by 1 byte (operation byte)
                // We shift it right by 96 bits (256 - 160 [20 address bytes]) to right-align the data and zero out unused data.
                let to := shr(0x60, mload(add(transactions, add(i, 0x01))))
                // We offset the load address by 21 byte (operation byte + 20 address bytes)
                let value := mload(add(transactions, add(i, 0x15)))
                // We offset the load address by 53 byte (operation byte + 20 address bytes + 32 value bytes)
                let dataLength := mload(add(transactions, add(i, 0x35)))
                // We offset the load address by 85 byte (operation byte + 20 address bytes + 32 value bytes + 32 data length bytes)
                let data := add(transactions, add(i, 0x55))
                let success := 0
                switch operation
                case 0 {
                    success := call(gas(), to, value, data, dataLength, 0, 0)
                }
                // This version does not allow delegatecalls
                case 1 {
                    revert(0, 0)
                }
                if eq(success, 0) {
                    revert(0, 0)
                }
                // Next entry starts at 85 byte + data length
                i := add(i, add(0x55, dataLength))
            }
        }
    }
}
