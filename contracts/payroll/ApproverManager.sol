// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./Storage.sol";

contract ApproverManager is Storage, OwnableUpgradeable {
    event AddedApprover(address approver);
    event RemovedApprover(address approver);
    event ChangedThreshold(uint256 threshold);

    /**
     * @notice Sets the initial storage of the contract.
     * @param _approvers List of Org approvers.
     * @param _threshold Number of required confirmations for a Org transaction.
     */
    function setupApprovers(
        address[] calldata _approvers,
        uint128 _threshold
    ) internal {
        // Threshold can only be 0 at initialization.
        // Check ensures that setup function can only be called once.
        require(threshold == 0, "CS015");
        // Validate that threshold is smaller than number of added approvers.
        require(_threshold <= _approvers.length, "CS016");
        // There has to be at least one Org approver.
        require(_threshold >= 1, "CS015");
        // Initializing Org approvers.
        address currentApprover = SENTINEL_APPROVER;
        for (uint256 i = 0; i < _approvers.length; i++) {
            // Approver address cannot be null.
            address approver = _approvers[i];
            require(
                approver != address(0) &&
                    approver != SENTINEL_APPROVER &&
                    approver != address(this) &&
                    currentApprover != approver,
                "CS003"
            );
            // No duplicate approvers allowed.
            require(approvers[approver] == address(0), "CS002");
            approvers[currentApprover] = approver;
            currentApprover = approver;
        }
        approvers[currentApprover] = SENTINEL_APPROVER;
        approverCount = uint128(_approvers.length);
        threshold = _threshold;
    }

    /**
     * @notice Adds the approver `approver` to the Org and updates the threshold to `_threshold`.
     * @dev This can only be done via a Org transaction.
     * @param approver New approver address.
     * @param _threshold New threshold.
     */
    function addApproverWithThreshold(
        address approver,
        uint128 _threshold
    ) public onlyOwner {
        // Approver address cannot be null, the sentinel or the Org itself.
        require(
            approver != address(0) &&
                approver != SENTINEL_APPROVER &&
                approver != address(this),
            "CS001"
        );
        // No duplicate approvers allowed.
        require(approvers[approver] == address(0), "CS001");
        approvers[approver] = approvers[SENTINEL_APPROVER];
        approvers[SENTINEL_APPROVER] = approver;
        approverCount++;
        emit AddedApprover(approver);
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
        require(approverCount - 1 >= _threshold, "GS201");
        // Validate approver address and check that it corresponds to approver index.
        require(
            approver != address(0) && approver != SENTINEL_APPROVER,
            "CS001"
        );
        require(approvers[prevApprover] == approver, "CS001");
        approvers[prevApprover] = approvers[approver];
        approvers[approver] = address(0);
        approverCount--;
        emit RemovedApprover(approver);
        // Change threshold if threshold was changed.
        if (threshold != _threshold) changeThreshold(_threshold);
    }

    /**
     * @notice Replaces the approver `oldApprover` in the Org with `newApprover`.
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
        require(
            newApprover != address(0) &&
                newApprover != SENTINEL_APPROVER &&
                newApprover != address(this),
            "CS001"
        );
        // No duplicate approvers allowed.
        require(approvers[newApprover] == address(0), "CS001");
        // Validate oldApprover address and check that it corresponds to approver index.
        require(
            oldApprover != address(0) && oldApprover != SENTINEL_APPROVER,
            "CS001"
        );
        require(approvers[prevApprover] == oldApprover, "CS001");
        approvers[newApprover] = approvers[oldApprover];
        approvers[prevApprover] = newApprover;
        approvers[oldApprover] = address(0);
        emit RemovedApprover(oldApprover);
        emit AddedApprover(newApprover);
    }

    /**
     * @notice Changes the threshold of the Org to `_threshold`.
     * @dev This can only be done via a Org transaction.
     * @param _threshold New threshold.
     */
    function changeThreshold(uint128 _threshold) public onlyOwner {
        // Validate that threshold is smaller than number of approvers.
        require(_threshold <= approverCount, "CS016");
        // There has to be at least one Org approver.
        require(threshold != 0, "CS015");
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
}
