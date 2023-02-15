//contracts/Organizer.sol
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./payroll/ApproverManager.sol";
// import "./organizer/ApprovalMatrix.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
// import "./organizer/PayoutManager.sol";
import "./payroll/PayrollManager.sol";

/// @title Organizer - A utility smart contract for Orgss to define and manage their Organizational structure.
/// @author Sriram Kasyap Meduri - <sriram@parcel.money>
/// @author Krishna Kant Sharma - <krishna@parcel.money>

contract Organizer is ApproverManager, Pausable, PayrollManager {
    //  Events
    //  Org Onboarded
    event OrgOnboarded(
        address indexed orgAddress,
        address[] indexed approvers,
        address[] approvers2
    );

    //  new Org approver added
    //  Orgs  Approvers modified
    //  Orgs  Approvers removed
    //  Deal created
    //  Payout created
    //  Payout executed
    //  Payout cancelled
    //  Deal cancelled
    //  Orgs Offboarded
    event OrgOffboarded(address indexed orgAddress);

    // Custom Allowance Module Address
    constructor(address _allowanceAddress, address _masterOperator) {
        ALLOWANCE_MODULE = _allowanceAddress;
        MASTER_OPERATOR = _masterOperator;
    }

    //  Onboard an Org
    function onboard(
        address[] calldata _approvers,
        uint256 approvalsRequired
    ) external {
        address safeAddress = msg.sender;

        require(_approvers.length > 0, "CS000");

        require(_approvers.length >= approvalsRequired, "CS000");

        address currentapprover = SENTINEL_ADDRESS;

        orgs[safeAddress].approverCount = 0;
        orgs[safeAddress].approvalsRequired = approvalsRequired;

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

            // TODO: emit Approver added event
            orgs[safeAddress].approverCount++;
        }
        orgs[safeAddress].approvers[currentapprover] = SENTINEL_ADDRESS;
        emit OrgOnboarded(safeAddress, _approvers, _approvers);
    }

    // Off-board an Org
    function offboard(
        address _safeAddress
    )
        external
        onlyOnboarded(_safeAddress)
        onlyApproverOrMultisig(_safeAddress)
    {
        // Remove all approvers in Orgs
        address currentapprover = orgs[_safeAddress].approvers[
            SENTINEL_ADDRESS
        ];
        while (currentapprover != SENTINEL_ADDRESS) {
            address nextapprover = orgs[_safeAddress].approvers[
                currentapprover
            ];
            delete orgs[_safeAddress].approvers[currentapprover];
            currentapprover = nextapprover;
        }

        delete orgs[_safeAddress];
        emit OrgOffboarded(_safeAddress);
    }
}