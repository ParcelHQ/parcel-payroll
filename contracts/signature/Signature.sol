// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../payroll/ApproverManager.sol";

// Errors
error InvalidSignatureLength();

/**
 * @title Signature
 * @notice - This contract is has the logic to verify the signatures related to the payroll transactions
 * @author Krishna Kant Sharma - <krishna@parcel.money>
 */
contract Signature is ApproverManager {
    using ECDSA for bytes32;

    /**
     * @dev - Typehash of the EIP712 Domain
     */
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    /**
     * @dev - Typehash of the Payroll Transaction
     */
    bytes32 internal constant PAYROLL_TX_TYPEHASH =
        keccak256("PayrollTx(bytes32 rootHash)");

    /**
     * @dev - Typehash of the Nonce Cancelation
     */
    bytes32 internal constant CANCEL_NONCE =
        keccak256("CancelNonce(uint64 nonce)");

    /**
     * @dev generate the hash of the payroll transaction
     * @param rootHash hash = hash of the merkle roots signed by the approver
     * @return bytes32 hash
     */
    function generateTransactionHash(
        bytes32 rootHash
    ) public view returns (bytes32) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                getDomainSeparator(),
                keccak256(abi.encode(PAYROLL_TX_TYPEHASH, rootHash))
            )
        );
        return digest;
    }

    /**
     * @dev generate the hash of the cancel transaction
     * @param nonce nonce of the payout
     * @return bytes32 hash
     */
    function getCancelTransactionHash(
        uint64 nonce
    ) public view returns (bytes32) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                getDomainSeparator(),
                keccak256(abi.encode(CANCEL_NONCE, nonce))
            )
        );
        return digest;
    }

    /**
     * @dev get the domain separator
     * @return bytes32 domain separator
     * @dev - This function is uses cached domain separator when possible to save gas
     */
    function getDomainSeparator() internal view returns (bytes32) {
        if (address(this) == _cachedThis && block.chainid == _cachedChainId) {
            return _cachedDomainSeparator;
        } else {
            return _buildDomainSeparator(address(this));
        }
    }

    /**
     * @dev Build the domain separator
     * @param proxy address of the proxy contract
     * @return bytes32 domain separator
     */
    function _buildDomainSeparator(
        address proxy
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN_TYPEHASH,
                    keccak256(bytes(NAME)),
                    keccak256(bytes(VERSION)),
                    block.chainid,
                    proxy
                )
            );
    }

    /**
     * @dev split the signature into v, r, s
     * @param signature bytes32 signature
     * @return v uint8 v
     * @return r bytes32 r
     * @return s bytes32 s
     */
    function splitSignature(
        bytes memory signature
    ) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        if (signature.length != 65) revert InvalidSignatureLength();

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(signature, 32))
            // second 32 bytes
            s := mload(add(signature, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(signature, 96)))
        }
    }

    /**
     * @dev validate the signature of the payroll transaction
     * @param rootHash hash = encodeTransactionData(recipient, tokenAddress, amount, nonce)
     * @param signature signature of the rootHash
     * @return address of the signer
     */
    function validatePayrollTxHashes(
        bytes32 rootHash,
        bytes memory signature
    ) internal view returns (address) {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(signature);

        bytes32 digest = generateTransactionHash(rootHash);

        if (v > 30) {
            // If v > 30 then default va (27,28) has been adjusted for eth_sign flow
            // To support eth_sign and similar we adjust v
            // and hash the messageHash with the Ethereum message prefix before applying recover
            digest = keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", digest)
            );
            v -= 4;
        }

        return digest.recover(v, r, s);
    }

    /**
     * @dev validate the signature to cancel nonce
     * @param nonce nonce of the payout
     * @param signature signature of the nonce
     * @return address of the signer
     */
    function validateCancelNonce(
        uint64 nonce,
        bytes memory signature
    ) internal view returns (address) {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(signature);

        bytes32 digest = getCancelTransactionHash(nonce);

        if (v > 30) {
            // If v > 30 then default va (27,28) has been adjusted for eth_sign flow
            // To support eth_sign and similar we adjust v
            // and hash the messageHash with the Ethereum message prefix before applying recover
            digest = keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", digest)
            );
            v -= 4;
        }

        return digest.recover(v, r, s);
    }
}
