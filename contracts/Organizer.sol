//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./payroll/ApproverManager.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./payroll/PayrollManager.sol";

/// @title Organizer - A utility smart contract for Orgss to define and manage their Organizational structure.
/// @author Sriram Kasyap Meduri - <sriram@parcel.money>
/// @author Krishna Kant Sharma - <krishna@parcel.money>

contract Organizer is
    Initializable,
    OwnableUpgradeable,
    ApproverManager,
    PayrollManager
{
    //  Events
    //  Org Onboarded
    event OrgOnboarded(
        address indexed orgAddress,
        address[] indexed approvers,
        address[] approvers2
    );

    //  Org Offboarded
    event OrgOffboarded(address indexed orgAddress);

    /**
     * @dev Initializer for proxy contract
     * @param _allowanceAddress - Address of the Allowance Module on current Network
     */
    function initialize(address _allowanceAddress) public initializer {
        __Ownable_init();
        ALLOWANCE_MODULE = _allowanceAddress;
    }

    /**
     * @dev Onboard an Org with approvers
     * @param _approvers - Array of approver addresses
     * @param approvalsRequired - Number of approvals required for a payout to be executed
     */
    function onboard(
        address[] calldata _approvers,
        uint128 approvalsRequired
    ) external whenNotPaused {
        address safeAddress = msg.sender;

        require(
            orgs[safeAddress].approverCount == 0,
            "Organizer: Org already onboarded"
        );

        require(_approvers.length > 0, "CS000");

        require(_approvers.length >= approvalsRequired, "CS000");

        require(approvalsRequired != 0, "CS004");

        address currentapprover = SENTINEL_ADDRESS;

        orgs[safeAddress].approverCount = 0;
        orgs[safeAddress].approvalsRequired = approvalsRequired;
        orgs[safeAddress].packedPayoutNonces = new uint256[](5);

        for (uint256 i = 0; i < _approvers.length; i++) {
            address approver = _approvers[i];
            require(
                // approver address cannot be null.
                approver != address(0) &&
                    // approver address cannot be SENTINEL.
                    approver != SENTINEL_ADDRESS &&
                    // approver address cannot be same as contract.
                    approver != address(this) &&
                    // approver address cannot be same as previous.
                    currentapprover != approver,
                "CS001"
            );

            // No duplicate approvers allowed.
            require(
                orgs[safeAddress].approvers[approver] == address(0),
                "CS002"
            );
            orgs[safeAddress].approvers[currentapprover] = approver;
            currentapprover = approver;

            emit ApproverAdded(safeAddress, approver);

            orgs[safeAddress].approverCount++;
        }
        orgs[safeAddress].approvers[currentapprover] = SENTINEL_ADDRESS;
        emit OrgOnboarded(safeAddress, _approvers, _approvers);
    }

    /**
     * @dev Offboard an Org, remove all approvers and delete the Org
   
     */
    function offboard() external {
        _onlyOnboarded(msg.sender);

        // Remove all approvers in Orgs
        address currentapprover = orgs[msg.sender].approvers[SENTINEL_ADDRESS];
        while (currentapprover != SENTINEL_ADDRESS) {
            address nextapprover = orgs[msg.sender].approvers[currentapprover];
            delete orgs[msg.sender].approvers[currentapprover];
            currentapprover = nextapprover;
        }

        delete orgs[msg.sender];
        emit OrgOffboarded(msg.sender);
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
        revert("Ownable: cannot renounce ownership");
    }

    // /**
    //  * @dev Override _msgData from ContextUpgradeable
    //  */
    // function _msgData() internal view override(Context, ContextUpgradeable) returns (bytes memory) {
    //     return Context._msgData();
    // }

    // /**
    //  * @dev Override _msgSender from ContextUpgradeable
    //  */
    // function _msgSender() internal view override(Context, ContextUpgradeable) returns (address ) {
    //     return Context._msgSender();
    // }
}
