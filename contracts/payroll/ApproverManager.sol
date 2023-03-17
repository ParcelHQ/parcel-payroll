// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./Storage.sol";

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

contract ApproverManager is Storage, OwnableUpgradeable {
    // Events
    event AddedApprover(address approver);
    event RemovedApprover(address approver);
    event ChangedThreshold(uint256 threshold);

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
        if (threshold == 0) revert ThresholdTooLow(_threshold);

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
