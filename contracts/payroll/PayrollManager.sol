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
    // Null Pointer for linked list
    bytes32 public constant NULL_BYTES = bytes32(0);

    // Sentinel for linked list
    bytes32 public constant SENTINEL_BYTES = keccak256("SENTINEL");

    // Linked list of approved roots
    mapping (bytes32 => bytes32) approvedRoots;
    
    // Mapping of tokens to Fetch in current cycle
    mapping (address => uint96) public tokensToFetch;

    // List of token Addresses to fetch
    address[] paymentTokens;

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
     * @param paymentTokens Array of payment tokens to fetch from Multisig
     * @param payoutAmounts Array of payout amounts to fetch from Multisig
     */
    function validatePayouts(
        address safeAddress,
        bytes32[] memory roots,
        bytes[] memory signatures,
        address[] memory paymentTokens,
        uint96[] memory payoutAmounts
    ) external onlyOnboarded(safeAddress) {
        require(roots.length == signatures.length, "CS004");
        require(paymentTokens.length == payoutAmounts.length, "CS004");

        bool isNewAdded;
        for (uint96 i = 0; i < roots.length; i++) {
            if (!approvedNodes[roots[i]]) {
                address signer = validatePayrollTxHashes(
                    roots[i],
                    signatures[i]
                );
                require(_isApprover(safeAddress, signer), "CS014");
                approvedNodes[roots[i]] = true;
                isNewAdded = true;
            }
        }

        if (isNewAdded) {
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
                // Create Ether or IRC20 Transfer
                IERC20 erc20 = IERC20(tokenAddress);
                erc20.transfer(to, amount);
                packPayoutNonce(true, payoutNonce);
            }
        }
    }

    /**
     * @dev Validates and Executes a list of payouts in a single transaction
     * @param recipients Addresses to send the funds to
     * @param tokenAddresses Addresses of the token to send
     * @param amounts Amounts of tokens to send
     * @param payoutNonces Payout nonces to use
     * @param safeAddress Address of the Org
     * @param proofs Array of merkle proofs to validate
     * @param roots Array of merkle roots to validate
     * @param rootSignatures Array of signatures to validate the roots
     */
    function executePayouts(
        address payable[] calldata recipients,
        address[] calldata tokenAddresses,
        uint256[] calldata amounts,
        uint64[] calldata payoutNonces,
        address safeAddress,
        bytes32[][][] calldata proofs,
        bytes32[][] calldata roots,
        bytes[][] memory rootSignatures
    ) external onlyOnboarded(safeAddress) {
        // Validate input lengths to prevent out of bounds errors
        require(recipients.length == tokenAddresses.length, "CS004");
        require(recipients.length == amounts.length, "CS004");
        require(recipients.length == payoutNonces.length, "CS004");
        require(recipients.length == proofs.length, "CS004");
        require(recipients.length == roots.length, "CS004");
        require(recipients.length == rootSignatures.length, "CS004");

        // Memory for Approved payouts
        bool[] memory approvedPayouts = new bool[](recipients.length);

        // Loop through all payouts
        for (uint96 i = 0; i < recipients.length; i++) {

            // If the payout nonce is already packed, revert the transaction
            if (packedPayoutNonces.length != 0 && getPayoutNonce(payoutNonces[i])) {
                revert("CS017");
            }

            // Initialize the number of approvals for the current payout
            uint8 approvals = 0;
            
            // Get the leaf hash for the current payout
            bytes32 leaf = encodeTransactionData(
                recipients[i],
                tokenAddresses[i],
                amounts[i],
                payoutNonces[i]
            );
            
            // For each payout, loop through all roots 
            for (uint96 j = 0; j < roots[i].length; j++) {
                
                // For each root, check if it is a part of approvedRoots
                // If it is not, the mapping will return 0x00 (NULL_BYTES)
                if (approvedRoots[roots[i][j]] == NULL_BYTES) {
                    
                    // Validate the root against the signature
                    address signer = validatePayrollTxHashes(
                        roots[i][j],
                        rootSignatures[i][j]
                    );
                        // If the root is from a valid approver, add it to approvedRoots
                        if (_isApprover(safeAddress, signer)) { 
                            approvedRoots[roots[i][j]] = approvedRoots[SENTINEL_BYTES];
                            approvedRoots[SENTINEL_BYTES] = roots[i][j];
                        }
                        // Else, revert
                        else {
                            revert("CS014");
                        }
                }
                    // If it is part of approvedRoots, verify if current leaf is part of the root
                if (MerkleProof.verify(proofs[i][j], roots[i][j], leaf)) {
                    // If it is, increment approval count
                    approvals += 1;
                    // If the token amount to be fetched is 0, it gets added in next step.
                    // So add the token to the paymentTokens array
                    if (tokensToFetch[tokenAddresses[i]] == 0) {
                        paymentTokens.push(tokenAddresses[i]);
                    }

                    // Increment amount to be fetched from the allowance module
                    tokensToFetch[tokenAddresses[i]] += uint96(amounts[i]);
                } else {
                    // Else, revert
                    revert("CS016");
                }
            }

            // If approval count is greater than or equal to approvalsRequired, mark payout as approved
            if (approvals >= orgs[safeAddress].approvalsRequired) {
                approvedPayouts[i] = true;
            }
        }

        // Fetch all tokens from the Safe
        for (uint96 index = 0; index < paymentTokens.length; index++) {
            execTransactionFromGnosis(
                safeAddress,
                paymentTokens[index],
                tokensToFetch[paymentTokens[index]],
                bytes("")
            );
            // Delete the token from the tokensToFetch array
            delete tokensToFetch[paymentTokens[index]];
        }
        


        // For each payout, if it is approved, execute it
        for (uint96 i = 0; i < recipients.length; i++) {
            if (approvedPayouts[i]) {
                // Create Ether or IRC20 Transfer
                IERC20 erc20 = IERC20(tokenAddresses[i]);
                erc20.transfer(recipients[i], amounts[i]);
                packPayoutNonce(true, payoutNonces[i]);
            }
        }

        // Clean up the paymentTokens array
        delete paymentTokens;

        // Clean up the approvedRoots linked list
        while (approvedRoots[SENTINEL_BYTES] != NULL_BYTES) {
            bytes32 root = approvedRoots[SENTINEL_BYTES];
            approvedRoots[SENTINEL_BYTES] = approvedRoots[root];
            delete approvedRoots[root];
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
