// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Signature {
    using ECDSA for bytes32;

    // Domain Typehash
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256(
            bytes("EIP712Domain(uint256 chainId,address verifyingContract)")
        );

    // Message Typehash
    bytes32 internal constant PAYROLL_TX_TYPEHASH =
        keccak256(bytes("PayrollTx(bytes32 rootHash)"));

    function getChainId() internal view returns (uint256 chainId) {
        assembly {
            chainId := chainid()
        }
    }

    /**
     * @dev get the domain seperator
     */
    function getDomainSeperator() internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(EIP712_DOMAIN_TYPEHASH, getChainId(), address(this))
            );
    }

    function splitSignature(
        bytes memory signature
    ) public pure returns (uint8 v, bytes32 r, bytes32 s) {
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
                getDomainSeperator(),
                keccak256(abi.encode(PAYROLL_TX_TYPEHASH, rootHash))
            )
        );
        return digest;
    }

    /**
     * @dev validate the signature of the payroll transaction
     * @param rootHash hash = encodeTransactionData(recipient, tokenAddress, amount, nonce)
     * @param signature signature
     */
    function validatePayrollTxHashes(
        bytes32 rootHash,
        bytes memory signature
    ) external view returns (address) {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(signature);

        if (v > 30) {
            bytes32 payrollHash = generateTransactionHash(rootHash);

            bytes32 digest = keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    payrollHash
                )
            );
            return ECDSA.recover(digest, v - 4, r, s);
        }
        if (v == 1) {
            return address(uint160(uint256(r)));
        } else {
            bytes32 digest = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    getDomainSeperator(),
                    keccak256(abi.encode(PAYROLL_TX_TYPEHASH, rootHash))
                )
            );

            return digest.recover(signature);
        }
    }
}
