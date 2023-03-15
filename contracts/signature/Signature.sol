// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../payroll/Storage.sol";

contract Signature is Storage {
    using ECDSA for bytes32;

    // Domain Typehash
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256(
            bytes(
                "EIP712Domain(string version, uint256 chainId,address verifyingContract)"
            )
        );

    // Payroll Transaction Typehash
    bytes32 internal constant PAYROLL_TX_TYPEHASH =
        keccak256(bytes("PayrollTx(bytes32 rootHash)"));

    function getChainId() internal view returns (uint256 chainId) {
        assembly {
            chainId := chainid()
        }
    }

    /**
     * @dev get the domain separator
     * @return bytes32 domain separator
     */
    function getDomainSeparator() internal view returns (bytes32) {
        if (address(this) == _cachedThis && block.chainid == _cachedChainId) {
            return _cachedDomainSeparator;
        } else {
            return _buildDomainSeparator();
        }
    }

    /**
     * @dev Build the domain separator
     * @return bytes32 domain separator
     */
    function _buildDomainSeparator() internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN_TYPEHASH,
                    VERSION,
                    getChainId(),
                    address(this)
                )
            );
    }

    function splitSignature(
        bytes memory signature
    ) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        require(signature.length == 65, "invalid signature length");

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(signature, 32))
            // second 32 bytes
            s := mload(add(signature, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(signature, 96)))
        }
    }

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
     * @dev validate the signature of the payroll transaction
     * @param rootHash hash = encodeTransactionData(recipient, tokenAddress, amount, nonce)
     * @param signature signature
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
}
