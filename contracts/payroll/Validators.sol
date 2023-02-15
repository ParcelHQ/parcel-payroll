//contracts/Organizer.sol
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./Storage.sol";

/// @title Validators for Organizer Contract
abstract contract Validators is Storage {
    /**
     * @dev Check if the address is an approver on the Org
     * @param _safeAddress Address of the Org
     * @param _addressToCheck Address to check
     * @return bool true if the address is an approver
     */
    function isApprover(
        address _safeAddress,
        address _addressToCheck
    ) public view returns (bool) {
        require(_addressToCheck != address(0), "CS001");
        require(_addressToCheck != SENTINEL_ADDRESS, "CS001");
        require(isOrgOnboarded(_safeAddress), "CS009");
        return _isApprover(_safeAddress, _addressToCheck);
    }

    /**
     * @dev Check if the address is an approver
     * @param _safeAddress Address of the Org
     * @param _addressToCheck Address to check
     * @return bool true if the address is an approver
     */
    function _isApprover(
        address _safeAddress,
        address _addressToCheck
    ) internal view returns (bool) {
        return orgs[_safeAddress].approvers[_addressToCheck] != address(0);
    }

    /**
     * @dev Check if the Org is onboarded
     * @param _addressToCheck Address of the Org
     * @return bool true if the Org is onboarded
     */
    function isOrgOnboarded(
        address _addressToCheck
    ) public view returns (bool) {
        require(_addressToCheck != address(0), "CS003");
        return orgs[_addressToCheck].approverCount > 0;
    }
}
