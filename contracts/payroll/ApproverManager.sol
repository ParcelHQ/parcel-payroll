// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// Errors
error DuplicateCallToSetupFunction();
error ThresholdTooHigh(uint256 threshold, uint256 approverCount);
error ThresholdTooLow(uint256 threshold);
error InvalidAddressProvided(address providedAddress);
error DuplicateAddressProvided(address providedAddress);
error ApproverDoesNotExist(address approver);
error ApproverAlreadyExists(address approver);
error OnlyApprover();
error UintOverflow();

/**
 * @title ApproverManager
 * @notice This contract manages the approvers for the Org.
 * @dev This contract is used by the Parcel Payroll contract.
 * @author Sriram Kasyap Meduri - <sriram@parcel.money>
 * @author Krishna Kant Sharma - <krishna@parcel.money>
 */
contract ApproverManager is OwnableUpgradeable {
    /**
     * @dev Storage layout of the contract.
     *
     *
     */

    /**
     * @dev The name of the contract.
     */
    string public constant NAME = "ParcelPayroll";

    /**
     * @dev The version of the contract.
     */
    string public constant VERSION = "1.0.0";

    /**
     * @dev The sentinel value for the linked list of approvers.
     */
    address internal constant SENTINEL_APPROVER = address(0x1);

    /**
     * @dev The address of the AllowanceModule contract.
     */
    address constant ALLOWANCE_MODULE =
        0xCFbFaC74C26F8647cBDb8c5caf80BB5b32E43134;

    /**
     * @dev Linked list of approvers.
     */
    mapping(address => address) internal approvers;

    /**
     * @dev Number of approvers.
     */
    uint128 internal approverCount;

    /**
     * @dev The threshold of approvers required to approve a payout.
     */
    uint128 public threshold;

    /**
     * @dev The payout nonce is used to prevent replay attacks
     * Each payout nonce is packed into a bit in a uint256. The bit is set to 1 if the nonce has been used and 0 if not.
     * This way, 256 nonces are packed into a single uint256 and stored in the value of packedPayoutNonces mapping.
     * The key of the mapping is the slot number of the payout. Each slot can store 256 nonces.
     * By using mapping, we can access any nonce in constant time.
     **/
    mapping(uint256 => uint256) packedPayoutNonces;

    /**
     * @dev The domain separator used for the EIP-712 signature, cached at initialisation.
     */
    bytes32 _cachedDomainSeparator;

    /**
     * @dev The chain ID of the network, cached at construction.
     */
    uint256 immutable _cachedChainId = block.chainid;

    /**
     * @dev The address of the Org contract, cached at initialisation.
     */
    address _cachedThis;

    /**
     * @dev Storage Gaps to prevent upgrade errors
     */
    uint256[48] __gap;

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
     * @dev Events emitted by the contract.
     *
     *
     */

    /**
     * @dev Emitted when a new approver is added.
     * @param approver The address of the approver added.
     */
    event AddedApprover(address approver);

    /**
     * @dev Emitted when an approver is removed.
     * @param approver The address of the approver removed.
     */
    event RemovedApprover(address approver);

    /**
     * @dev Emitted when the org threshold is changed.
     * @param threshold The new threshold.
     */
    event ChangedThreshold(uint256 threshold);

    /**
     * @dev Approver Management Functions
     *
     *
     */

    /**
     * @notice Adds the approver `approver` to the Org and updates the threshold to `_threshold`.
     * @dev This can only be done via a Org transaction.
     * @param newApprover New approver address.
     * @param _threshold New threshold.
     */
    function addApproverWithThreshold(
        address newApprover,
        uint128 _threshold
    ) public onlyOwner {
        // Approver address cannot be null, the sentinel, the contract or the Org itself.
        if (
            newApprover == address(0) ||
            newApprover == SENTINEL_APPROVER ||
            newApprover == address(this) ||
            newApprover == owner()
        ) revert InvalidAddressProvided(newApprover);

        // No duplicate approvers allowed.
        if (approvers[newApprover] != address(0))
            revert ApproverAlreadyExists(newApprover);

        approvers[newApprover] = approvers[SENTINEL_APPROVER];
        approvers[SENTINEL_APPROVER] = newApprover;
        approverCount++;
        emit AddedApprover(newApprover);
        // Change threshold if threshold was changed.
        if (threshold != _threshold) changeThreshold(_threshold);
    }

    /**
     * @notice Removes the approver `approver` from the Org and updates the threshold to `_threshold`.
     * @dev This can only be done via a Org transaction.
     * @param prevApprover Approver that pointed to the approver to be removed in the linked list
     * @param approver Approver address to be removed.
     * @param _threshold New threshold.
     */
    function removeApproverWithThreshold(
        address prevApprover,
        address approver,
        uint128 _threshold
    ) public onlyOwner {
        // Only allow to remove an approver, if threshold can still be reached.
        if (approverCount < _threshold)
            revert ThresholdTooHigh(_threshold, approverCount);

        // Validate approver address and check that it corresponds to approver index.
        if (approver == address(0) || approver == SENTINEL_APPROVER)
            revert InvalidAddressProvided(approver);

        if (approvers[prevApprover] != approver)
            revert ApproverDoesNotExist(approver);

        approvers[prevApprover] = approvers[approver];
        delete approvers[approver];
        approverCount--;
        emit RemovedApprover(approver);
        // Change threshold if threshold was changed.
        if (threshold != _threshold) changeThreshold(_threshold);
    }

    /**
     * @notice Replaces the approver `oldApprover` with `newApprover` in the Org.
     * @dev This can only be done via a Org transaction.
     * @param prevApprover Approver that pointed to the approver to be replaced in the linked list
     * @param oldApprover Approver address to be replaced.
     * @param newApprover New approver address.
     */
    function swapApprover(
        address prevApprover,
        address oldApprover,
        address newApprover
    ) public onlyOwner {
        // Approver address cannot be null, the sentinel or the Org itself.
        if (
            newApprover == address(0) ||
            newApprover == SENTINEL_APPROVER ||
            newApprover == owner() ||
            newApprover == address(this)
        ) revert InvalidAddressProvided(newApprover);

        // No duplicate approvers allowed.
        if (approvers[newApprover] != address(0))
            revert ApproverAlreadyExists(newApprover);

        // Validate oldApprover address and check that it corresponds to approver index.
        if (oldApprover == address(0) || oldApprover == SENTINEL_APPROVER)
            revert InvalidAddressProvided(oldApprover);

        if (approvers[prevApprover] != oldApprover)
            revert ApproverDoesNotExist(oldApprover);

        approvers[newApprover] = approvers[oldApprover];
        approvers[prevApprover] = newApprover;
        delete approvers[oldApprover];
        emit RemovedApprover(oldApprover);
        emit AddedApprover(newApprover);
    }

    /**
     * @notice Changes the threshold of the Org to `_threshold`.
     * @dev This can only be done via a Org transaction.
     * @param _threshold New threshold.
     */
    function changeThreshold(uint128 _threshold) public onlyOwner {
        // Validate that threshold is less than or equal to the number of approvers.
        if (_threshold > approverCount)
            revert ThresholdTooHigh(_threshold, approverCount);

        // There has to be at least one Org approver.
        if (_threshold == 0) revert ThresholdTooLow(_threshold);

        threshold = _threshold;
        emit ChangedThreshold(threshold);
    }

    /**
     * @notice Returns if `approver` is an approver of the Org.
     * @return Boolean if approver is an approver of the Org.
     */
    function isApprover(address approver) public view returns (bool) {
        return
            approver != SENTINEL_APPROVER && approvers[approver] != address(0);
    }

    /**
     * @notice Returns a list of Org approvers.
     * @return Array of Org approvers.
     */
    function getApprovers() public view returns (address[] memory) {
        address[] memory array = new address[](approverCount);

        // populate return array
        uint256 index = 0;
        address currentApprover = approvers[SENTINEL_APPROVER];
        while (currentApprover != SENTINEL_APPROVER) {
            array[index] = currentApprover;
            currentApprover = approvers[currentApprover];
            index++;
        }
        return array;
    }

    /**
     * @notice Sets the initial storage of the contract.
     * @param _approvers List of Org approvers.
     * @param _threshold Number of required confirmations for a Org transaction.
     */
    function setupApprovers(
        address[] calldata _approvers,
        uint128 _threshold
    ) internal {
        uint256 _approverLength = _approvers.length;
        // Threshold can only be 0 at initialization.
        // Check ensures that setup function can only be called once.
        if (threshold != 0) revert DuplicateCallToSetupFunction();
        // Validate that threshold is less than or equal to number of added approvers.
        if (_threshold > _approverLength)
            revert ThresholdTooHigh(_threshold, _approverLength);
        // There has to be at least one Org approver.
        if (_threshold < 1) revert ThresholdTooLow(_threshold);
        // Initializing Org approvers.
        address currentApprover = SENTINEL_APPROVER;
        for (uint256 i = 0; i < _approverLength; i++) {
            // Approver address cannot be null.
            address approver = _approvers[i];
            if (
                approver == address(0) ||
                approver == SENTINEL_APPROVER ||
                approver == address(this) ||
                approver == owner()
            ) revert InvalidAddressProvided(approver);

            if (
                currentApprover == approver || approvers[approver] != address(0)
            ) revert DuplicateAddressProvided(approver);

            approvers[currentApprover] = approver;
            currentApprover = approver;
        }
        approvers[currentApprover] = SENTINEL_APPROVER;
        approverCount = uint128(_approverLength);
        threshold = _threshold;
    }
}
