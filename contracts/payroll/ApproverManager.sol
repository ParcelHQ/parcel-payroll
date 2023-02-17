//contracts/Organizer.sol
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./Modifiers.sol";

/// @title Approver Manager for Organizer Contract
abstract contract ApproverManager is Modifiers {
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
        address safeAddress,
        address approver,
        uint128 threshold
    ) public onlyOnboarded(safeAddress) onlyMultisig(safeAddress) {
        // Approver address cannot be null, the sentinel or the Safe itself.
        require(
            approver != address(0) &&
                approver != SENTINEL_ADDRESS &&
                approver != address(this),
            "CS003"
        );
        // No duplicate approvers allowed.
        require(orgs[safeAddress].approvers[approver] == address(0), "CS002");

        orgs[safeAddress].approvers[approver] = orgs[safeAddress].approvers[
            SENTINEL_ADDRESS
        ];
        orgs[safeAddress].approvers[SENTINEL_ADDRESS] = approver;
        orgs[safeAddress].approverCount++;

        emit ApproverAdded(safeAddress, approver);
        // Change threshold if threshold was changed.
        if (threshold != orgs[safeAddress].approvalsRequired)
            changeThreshold(safeAddress, threshold);
    }

    /// @dev Allows to remove an approver from the Safe and update the threshold at the same time.
    ///      This can only be done via a Safe transaction.
    /// @notice Removes the approver `approver` from the Safe and updates the threshold to `threshold`.
    /// @param prevApprover Approver that pointed to the approver to be removed in the linked list
    /// @param approver Approver address to be removed.
    /// @param threshold New threshold.
    function removeApprover(
        address safeAddress,
        address prevApprover,
        address approver,
        uint128 threshold
    ) public onlyOnboarded(safeAddress) onlyMultisig(safeAddress) {
        // Only allow to remove an approver, if threshold can still be reached.
        require(orgs[safeAddress].approverCount - 1 >= threshold, "CS016");
        // Validate approver address and check that it corresponds to approver index.
        require(
            approver != address(0) && approver != SENTINEL_ADDRESS,
            "CS003"
        );
        require(orgs[safeAddress].approvers[prevApprover] == approver, "CS017");

        orgs[safeAddress].approvers[prevApprover] = orgs[safeAddress].approvers[
            approver
        ];
        orgs[safeAddress].approvers[approver] = address(0);
        orgs[safeAddress].approverCount--;
        emit RemovedApprover(approver, safeAddress);
        // Change threshold if threshold was changed.
        if (threshold != orgs[safeAddress].approvalsRequired)
            changeThreshold(safeAddress, threshold);
    }

    /// @dev Allows to swap/replace an approver with another address.
    ///      This can only be done via a Multisig transaction.
    /// @notice Replaces the approver `oldApprover` in the Safe with `newApprover`.
    /// @param prevApprover Approver that pointed to the approver to be replaced in the linked list
    /// @param oldApprover Approver address to be replaced.
    /// @param newApprover New approver address.
    function swapApprover(
        address safeAddress,
        address prevApprover,
        address oldApprover,
        address newApprover
    ) public onlyOnboarded(safeAddress) onlyMultisig(safeAddress) {
        // Approver address cannot be null, the sentinel or the Safe itself.
        require(
            newApprover != address(0) &&
                newApprover != SENTINEL_ADDRESS &&
                newApprover != address(this),
            "CS003"
        );
        // No duplicate approvers allowed.
        require(
            orgs[safeAddress].approvers[newApprover] == address(0),
            "CS002"
        );

        // Validate oldApprovers address and check that it corresponds to approver index.
        require(
            oldApprover != address(0) && oldApprover != SENTINEL_ADDRESS,
            "CS003"
        );

        require(
            orgs[safeAddress].approvers[prevApprover] == oldApprover,
            "CS017"
        );
        orgs[safeAddress].approvers[newApprover] = orgs[safeAddress].approvers[
            oldApprover
        ];
        orgs[safeAddress].approvers[prevApprover] = newApprover;
        orgs[safeAddress].approvers[oldApprover] = address(0);
        emit RemovedApprover(oldApprover, safeAddress);
        emit ApproverAdded(safeAddress, newApprover);
    }

    /// @dev Allows to update the number of required confirmations by Safe approvers.
    ///      This can only be done via a Multisig transaction.
    /// @notice Changes the approvals required to `_threshold`.
    /// @param threshold New threshold.
    function changeThreshold(
        address safeAddress,
        uint128 threshold
    ) public onlyOnboarded(safeAddress) onlyMultisig(safeAddress) {
        // Validate that threshold is smaller than number of approvers.
        require(threshold <= orgs[safeAddress].approverCount, "CS016");
        // There has to be at least one Safe Approver.
        require(threshold >= 1, "CS015");
        orgs[safeAddress].approvalsRequired = threshold;
        emit ChangedThreshold(threshold, safeAddress);
    }

    /**
     * @dev Get list of approvers for Org
     * @param _safeAddress Address of the Org
     * @return Array of approvers
     */
    function getApprovers(
        address _safeAddress
    ) public view onlyOnboarded(_safeAddress) returns (address[] memory) {
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
    ) external view onlyOnboarded(_safeAddress) returns (uint256) {
        return orgs[_safeAddress].approverCount;
    }

    /**
     * @dev Get required Threshold for Org
     * @param _safeAddress Address of the Org
     * @return Threshold Count
     */
    function getThreshold(
        address _safeAddress
    ) external view onlyOnboarded(_safeAddress) returns (uint256) {
        return orgs[_safeAddress].approvalsRequired;
    }
}
