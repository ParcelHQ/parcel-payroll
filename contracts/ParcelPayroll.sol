// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

import "./payroll/ApproverManager.sol";
import "./interfaces/IAllowanceModule.sol";

// Errors
error CannotRenounceOwnership();
error SweepFailed(address tokenAddress, uint256 amount);
error InvalidPayoutSignature(bytes signature);
error PayrollDataLengthMismatch();
error RootSignatureLengthMismatch();
error PaymentTokenLengthMismatch();
error TokensLeftInContract(address tokenAddress);
error PayoutNonceAlreadyExecuted(uint64 nonce);
error TokensNotSorted(address tokenAddress1, address tokenAddress2);
error UnauthorizedTransfer();
error InvalidSignatureLength();

/**
 * @title ParcelPayroll
 * @dev ParcelPayroll is a secure and decentralized smart contract designed to help organizations pay their contributors with ease and efficiency. The contract utilizes a dedicated approval team, removing the reliance on the organization's multisig, which helps to streamline the payment process and ensure secure payments.
 *
 * One of the key features of ParcelPayroll is its ability to improve approver coordination. Approvers can approve payouts in non-aligned batches, meaning they don't all need to approve the same payouts at the same time. This feature saves time and resources for the organization, as approvers can approve payouts when they are available, rather than being constrained by a strict schedule.
 *
 * With ParcelPayroll, organizations can automate their payment processes, reducing the risk of errors and increasing efficiency. The contract's decentralized architecture ensures that all transactions are transparent and auditable, adding an extra layer of security to the payment process.
 *
 * @author Sriram Kasyap Meduri - <sriram@parcel.money>
 * @author Krishna Kant Sharma - <krishna@parcel.money>
 */

contract ParcelPayroll is
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    ApproverManager
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using ECDSAUpgradeable for bytes32;

    /**
     * @dev Emitted when the contract is initialized
     * @param orgAddress - Address of the organization's safe
     * @param approvers - Array of approver addresses
     * @param approvalsRequired - Number of approvals required for a payout to be executed
     */
    event OrgSetup(
        address indexed orgAddress,
        address[] indexed approvers,
        uint128 approvalsRequired
    );

    /**
     * @dev Emitted when a payout is successfully executed
     * @param tokenAddress - Address of the token being paid out
     * @param to - Address of the recipient
     * @param amount - Amount being paid out
     * @param payoutNonce - Nonce of the payout
     */
    event PayoutSuccessful(
        address tokenAddress,
        address to,
        uint256 amount,
        uint256 payoutNonce
    );

    /**
     * @dev Emitted when a payout execution fails
     * @param tokenAddress - Address of the token being paid out
     * @param to - Address of the recipient
     * @param amount - Amount being paid out
     * @param payoutNonce - Nonce of the payout
     */
    event PayoutFailed(
        address tokenAddress,
        address to,
        uint256 amount,
        uint256 payoutNonce
    );

    /**
     * @dev Constructor
     */
    constructor() {
        // So that the contract cannot be initialized again and become singleton
        _disableInitializers();
    }

    /**
     * @dev Receive Native tokens
     */
    receive() external payable {}

    /**
     * @dev Initialize the payroll contract. Called when a new payroll contract is deployed / org is onboarded
     * @param _approvers - Array of approver addresses
     * @param approvalsRequired - Number of approvals required for a payout to be executed
     */
    function initialize(
        address safeAddress,
        address[] calldata _approvers,
        uint128 approvalsRequired
    ) external initializer {
        _transferOwnership(safeAddress);
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _cachedDomainSeparator = _buildDomainSeparator(address(this));
        _cachedThis = address(this);

        setupApprovers(_approvers, approvalsRequired);
        emit OrgSetup(safeAddress, _approvers, approvalsRequired);
    }

    /**
     * @dev Helper function to execute an ERC20 transfer safely for the try catch block. This can only be called by the contract itself
     * @param token - Address of the token to transfer
     * @param to - Address of the recipient
     * @param amount - Amount to transfer
     */
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
        // Caching array lengths
        uint128 payoutLength = uint128(to.length);
        uint128 rootLength = uint128(roots.length);
        bool[] memory isApproved = new bool[](payoutLength);

        // Validate the Input Data
        if (
            payoutLength == 0 ||
            payoutLength != tokenAddress.length ||
            payoutLength != amount.length ||
            payoutLength != payoutNonce.length
        ) revert PayrollDataLengthMismatch();

        if (rootLength != signatures.length)
            revert RootSignatureLengthMismatch();

        validateSignatures(roots, signatures);

        {
            // Initialize the flag token amount to fetch
            uint256 tokenFlagAmountToFetch = 0;

            // Initialize the flag token address
            address tokenFlag = tokenAddress[0];

            // Initialize the approvals array

            // Loop through the payouts
            for (uint256 i = 0; i < payoutLength; i++) {
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
                    j < rootLength && approvals < threshold;
                    j++
                ) {
                    // Verify the root has been validated
                    // Verify the proof against the current root and increment the approvals counter

                    if (
                        MerkleProofUpgradeable.verify(
                            proof[i][j],
                            roots[j],
                            leaf
                        )
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
        }
        // Loop through the approvals
        for (uint256 i = 0; i < payoutLength; i++) {
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
            } else {
                emit PayoutFailed(
                    tokenAddress[i],
                    to[i],
                    amount[i],
                    payoutNonce[i]
                );
            }
        }
    }

    /**
     * @dev Sweep the contract balance
     * @param tokenAddress - Address of the token to sweep
     */
    function sweep(address tokenAddress) external nonReentrant {
        if (tokenAddress == address(0)) {
            // Transfer native tokens
            (bool sent, bytes memory data) = owner().call{
                value: address(this).balance
            }("");

            if (!sent) revert SweepFailed(address(0), address(this).balance);
        } else {
            IERC20Upgradeable IERC20Token = IERC20Upgradeable(tokenAddress);
            try
                this.safeTransferExternal(
                    IERC20Token,
                    owner(),
                    IERC20Token.balanceOf(address(this))
                )
            {
                // Transfer ERC20 tokens
            } catch {
                revert SweepFailed(
                    tokenAddress,
                    IERC20Token.balanceOf(address(this))
                );
            }
        }
    }

    /**
     * @dev Cancel a payout nonce
     * @param nonce nonce of the payout
     * @param signature signature of the nonce
     */
    function invalidateNonce(uint64 nonce, bytes memory signature) external {
        // Check if the nonce is valid

        address signer = validateCancelNonce(nonce, signature);

        if (!isApprover(signer)) {
            revert OnlyApprover();
        }

        // Invalidate the nonce
        packPayoutNonce(nonce);
    }

    /**
     * @dev Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Renounce ownership of the contract
     * @notice This function is overridden to prevent renouncing ownership
     */
    function renounceOwnership() public view override onlyOwner {
        revert CannotRenounceOwnership();
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
     * @dev Get usage status of a payout nonce
     * @param payoutNonce Payout nonce to check
     * @return Boolean, true for used, false for unused
     */
    function getPayoutNonce(uint256 payoutNonce) public view returns (bool) {
        // Each payout nonce is packed into a uint256, so the index of the uint256 in the array is the payout nonce / 256
        uint256 slotIndex = uint248(payoutNonce >> 8);

        // The bit index of the uint256 is the payout nonce % 256 (0-255)
        uint256 bitIndex = uint8(payoutNonce);

        // If the bit is set, the payout nonce has been used, if not, it has not been used
        return (packedPayoutNonces[slotIndex] & (1 << bitIndex)) != 0;
    }

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
        uint256 rootLength = roots.length;
        // Validate the roots via approver signatures
        address currentApprover;
        for (uint256 i = 0; i < rootLength; ) {
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

            unchecked {
                i++;
            }
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
        uint256 contractBalance;
        if (tokenAddress != address(0)) {
            contractBalance = IERC20Upgradeable(tokenAddress).balanceOf(
                address(this)
            );
        } else {
            contractBalance = address(this).balance;
        }

        // If the contract balance is greater than or equal to the required amount, no need to fetch more tokens from safe
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

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

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
