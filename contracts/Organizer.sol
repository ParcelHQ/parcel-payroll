// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./payroll/ApproverManager.sol";
import "./payroll/PayrollManager.sol";

/// @title Organizer - A utility smart contract for Orgss to define and manage their Organizational structure.
/// @author Sriram Kasyap Meduri - <sriram@parcel.money>
/// @author Krishna Kant Sharma - <krishna@parcel.money>

contract Organizer is UUPSUpgradeable, PayrollManager, ApproverManager {
    //  Events
    //  Org Onboarded
    event OrgSetup(address indexed orgAddress, address[] indexed approvers);

    constructor() {
        // Set the threshold to 1, so that the contract can be initialized again and become singleton
        threshold = 1;
    }

    /**
     * @dev initialize the contract
     */
    function initialize() public initializer {
        __Ownable_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
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
        setupApprovers(_approvers, approvalsRequired);
        emit OrgSetup(msg.sender, _approvers);
    }

    /**
     * @dev Sweep the contract balance
     * @param tokenAddress - Address of the token to sweep
     */
    function sweep(address tokenAddress) external onlyOwner {
        if (tokenAddress == address(0)) {
            payable(msg.sender).transfer(address(this).balance);
        } else {
            IERC20(tokenAddress).transfer(
                msg.sender,
                IERC20(tokenAddress).balanceOf(address(this))
            );
        }
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

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
