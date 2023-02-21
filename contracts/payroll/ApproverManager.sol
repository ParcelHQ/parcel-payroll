//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Storage.sol";

/// @title Approver Manager for Organizer Contract
abstract contract ApproverManager is Storage {
    // Events
    event ApproverAdded(address indexed safeAddress, address indexed operator);
    event ApproverRemoved(
        address indexed safeAddress,
        address indexed operator
    );

    event RemovedApprover(address approver, address safeAddress);

    event ChangedThreshold(uint128 threshold, address safeAddress);

    /// @dev Allows to add a new approver to the Safe and update the threshold at the same time.
    ///      This can only be done via a Safe transaction.
    /// @notice Adds the approver `approver` to the Safe and updates the threshold to `threshold`.
    /// @param approver New approver address.
    /// @param threshold New threshold.
    function addApproverWithThreshold(
        address approver,
        uint128 threshold
    ) public whenNotPaused {
        _onlyOnboarded(msg.sender);

        // Approver address cannot be null, the sentinel or the Safe itself.
        require(
            approver != address(0) &&
                approver != SENTINEL_ADDRESS &&
                approver != address(this),
            "CS003"
        );
        // No duplicate approvers allowed.
        require(orgs[msg.sender].approvers[approver] == address(0), "CS002");

        orgs[msg.sender].approvers[approver] = orgs[msg.sender].approvers[
            SENTINEL_ADDRESS
        ];
        orgs[msg.sender].approvers[SENTINEL_ADDRESS] = approver;
        orgs[msg.sender].approverCount++;

        emit ApproverAdded(msg.sender, approver);
        // Change threshold if threshold was changed.
        if (threshold != orgs[msg.sender].approvalsRequired)
            changeThreshold(threshold);
    }

    /// @dev Allows to remove an approver from the Safe and update the threshold at the same time.
    ///      This can only be done via a Safe transaction.
    /// @notice Removes the approver `approver` from the Safe and updates the threshold to `threshold`.
    /// @param prevApprover Approver that pointed to the approver to be removed in the linked list
    /// @param approver Approver address to be removed.
    /// @param threshold New threshold.
    function removeApprover(
        address prevApprover,
        address approver,
        uint128 threshold
    ) public whenNotPaused {
        _onlyOnboarded(msg.sender);

        // Only allow to remove an approver, if threshold can still be reached.
        require(orgs[msg.sender].approverCount - 1 >= threshold, "CS016");
        // Validate approver address and check that it corresponds to approver index.
        require(
            approver != address(0) && approver != SENTINEL_ADDRESS,
            "CS003"
        );
        require(orgs[msg.sender].approvers[prevApprover] == approver, "CS017");

        orgs[msg.sender].approvers[prevApprover] = orgs[msg.sender].approvers[
            approver
        ];
        orgs[msg.sender].approvers[approver] = address(0);
        orgs[msg.sender].approverCount--;
        emit RemovedApprover(approver, msg.sender);
        // Change threshold if threshold was changed.
        if (threshold != orgs[msg.sender].approvalsRequired)
            changeThreshold(threshold);
    }

    /// @dev Allows to swap/replace an approver with another address.
    ///      This can only be done via a Multisig transaction.
    /// @notice Replaces the approver `oldApprover` in the Safe with `newApprover`.
    /// @param prevApprover Approver that pointed to the approver to be replaced in the linked list
    /// @param oldApprover Approver address to be replaced.
    /// @param newApprover New approver address.
    function swapApprover(
        address prevApprover,
        address oldApprover,
        address newApprover
    ) public whenNotPaused {
        _onlyOnboarded(msg.sender);

        // Approver address cannot be null, the sentinel or the Safe itself.
        require(
            newApprover != address(0) &&
                newApprover != SENTINEL_ADDRESS &&
                newApprover != address(this),
            "CS003"
        );
        // No duplicate approvers allowed.
        require(orgs[msg.sender].approvers[newApprover] == address(0), "CS002");

        // Validate oldApprovers address and check that it corresponds to approver index.
        require(
            oldApprover != address(0) && oldApprover != SENTINEL_ADDRESS,
            "CS003"
        );

        require(
            orgs[msg.sender].approvers[prevApprover] == oldApprover,
            "CS017"
        );
        orgs[msg.sender].approvers[newApprover] = orgs[msg.sender].approvers[
            oldApprover
        ];
        orgs[msg.sender].approvers[prevApprover] = newApprover;
        orgs[msg.sender].approvers[oldApprover] = address(0);
        emit RemovedApprover(oldApprover, msg.sender);
        emit ApproverAdded(msg.sender, newApprover);
    }

    /// @dev Allows to update the number of required confirmations by Safe approvers.
    ///      This can only be done via a Multisig transaction.
    /// @notice Changes the approvals required to `_threshold`.
    /// @param threshold New threshold.
    function changeThreshold(uint128 threshold) public whenNotPaused {
        _onlyOnboarded(msg.sender);

        // Validate that threshold is smaller than number of approvers.
        require(threshold <= orgs[msg.sender].approverCount, "CS016");
        // There has to be at least one Safe Approver.
        require(threshold >= 1, "CS015");
        orgs[msg.sender].approvalsRequired = threshold;
        emit ChangedThreshold(threshold, msg.sender);
    }

    /**
     * @dev Get list of approvers for Org
     * @param _safeAddress Address of the Org
     * @return Array of approvers
     */
    function getApprovers(
        address _safeAddress
    ) public view returns (address[] memory) {
        _onlyOnboarded(_safeAddress);

        address[] memory array = new address[](
            orgs[_safeAddress].approverCount
        );

        uint8 i = 0;
        address currentOp = orgs[_safeAddress].approvers[SENTINEL_ADDRESS];
        while (currentOp != SENTINEL_ADDRESS) {
            array[i] = currentOp;
            currentOp = orgs[_safeAddress].approvers[currentOp];
            i++;
        }

        return array;
    }

    /**
     * @dev Get count of approvers for Org
     * @param _safeAddress Address of the Org
     * @return Count of approvers
     */
    function getApproverCount(
        address _safeAddress
    ) external view returns (uint256) {
        _onlyOnboarded(_safeAddress);
        return orgs[_safeAddress].approverCount;
    }

    /**
     * @dev Get required Threshold for Org
     * @param _safeAddress Address of the Org
     * @return Threshold Count
     */
    function getThreshold(
        address _safeAddress
    ) external view returns (uint256) {
        _onlyOnboarded(_safeAddress);
        return orgs[_safeAddress].approvalsRequired;
    }

    function _onlyOnboarded(address _safeAddress) internal view {
        require(orgs[_safeAddress].approverCount != 0, "CS009");
    }
}
