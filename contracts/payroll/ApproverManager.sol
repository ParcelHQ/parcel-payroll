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

    /**
     * @dev Modify approvers for Org
     * @param _safeAddress Address of the Org
     * @param _addressesToAdd Array of addresses to add as approvers
     * @param _addressesToRemove Array of addresses to remove as approvers
     * @param newThreshold new threshold to updated according to new approvers
     */
    function modifyApprovers(
        address _safeAddress,
        address[] calldata _addressesToAdd,
        address[] calldata _addressesToRemove,
        uint256 newThreshold
    ) public onlyOnboarded(_safeAddress) onlyMultisig(_safeAddress) {
        require(newThreshold != 0, "CS015");

        for (uint256 i = 0; i < _addressesToAdd.length; i++) {
            address _addressToAdd = _addressesToAdd[i];
            require(
                _addressToAdd != address(0) &&
                    _addressToAdd != SENTINEL_ADDRESS &&
                    _addressToAdd != address(this) &&
                    _addressToAdd != _safeAddress,
                "CS001"
            );
            require(
                orgs[_safeAddress].approvers[_addressToAdd] == address(0),
                "CS002"
            );

            _addApprover(_safeAddress, _addressToAdd);
        }

        for (uint256 i = 0; i < _addressesToRemove.length; i++) {
            address _addressToRemove = _addressesToRemove[i];
            require(
                _addressToRemove != address(0) &&
                    _addressToRemove != SENTINEL_ADDRESS &&
                    _addressToRemove != address(this) &&
                    _addressToRemove != _safeAddress,
                "CS001"
            );
            require(
                orgs[_safeAddress].approvers[_addressToRemove] != address(0),
                "CS013"
            );

            _removeApprover(_safeAddress, _addressToRemove);
        }

        orgs[_safeAddress].approvalsRequired = newThreshold;
    }

    /**
     * @dev Add an approver to Org
     * @param _safeAddress Address of the Org
     * @param _approver Address of the approver
     */
    function _addApprover(address _safeAddress, address _approver) internal {
        orgs[_safeAddress].approvers[_approver] = orgs[_safeAddress].approvers[
            SENTINEL_ADDRESS
        ];
        orgs[_safeAddress].approvers[SENTINEL_ADDRESS] = _approver;
        orgs[_safeAddress].approverCount++;
    }

    // Remove an approver from a Orgs
    function _removeApprover(address _safeAddress, address _approver) internal {
        address cursor = SENTINEL_ADDRESS;
        while (orgs[_safeAddress].approvers[cursor] != _approver) {
            cursor = orgs[_safeAddress].approvers[cursor];
        }
        orgs[_safeAddress].approvers[cursor] = orgs[_safeAddress].approvers[
            _approver
        ];
        orgs[_safeAddress].approvers[_approver] = address(0);
        orgs[_safeAddress].approverCount--;
    }
}
