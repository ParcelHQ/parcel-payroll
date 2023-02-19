// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SignatureEIP712 {
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

    bytes32 internal DOMAIN_SEPARATOR =
        keccak256(
            abi.encode(EIP712_DOMAIN_TYPEHASH, getChainId(), address(this))
        );

    /**
     * @dev validate the signature of the payroll transaction
     * @param rootHash hash = encodeTransactionData(recipient, tokenAddress, amount, nonce)
     * @param signature signature
     */
    function validatePayrollTxHashes(
        bytes32 rootHash,
        bytes memory signature
    ) internal view returns (address) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PAYROLL_TX_TYPEHASH, rootHash))
            )
        );

        return digest.recover(signature);
    }
}
