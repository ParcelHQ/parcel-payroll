// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./payroll/ApproverManager.sol";
import "./payroll/PayrollManager.sol";

// Errors
error CannotRenounceOwnership();

/// @title ParcelPayroll - A utility smart contract for Orgs to define and manage their Organizational structure.
/// @author Sriram Kasyap Meduri - <sriram@parcel.money>
/// @author Krishna Kant Sharma - <krishna@parcel.money>

contract ParcelPayroll is UUPSUpgradeable, ApproverManager, PayrollManager {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    //  Events
    event OrgSetup(
        address indexed orgAddress,
        address[] indexed approvers,
        uint128 approvalsRequired
    );

    constructor() {
        // So that the contract cannot be initialized again and become singleton
        _disableInitializers();
    }

    /**
     * @dev Onboard an Org with approvers
     * @param _approvers - Array of approver addresses
     * @param approvalsRequired - Number of approvals required for a payout to be executed
     */
    function initialize(
        address[] calldata _approvers,
        uint128 approvalsRequired
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _cachedDomainSeparator = _buildDomainSeparator();
        _cachedThis = address(this);

        setupApprovers(_approvers, approvalsRequired);
        emit OrgSetup(msg.sender, _approvers, approvalsRequired);
    }

    /**
     * @dev Sweep the contract balance
     * @param tokenAddress - Address of the token to sweep
     */
    function sweep(address tokenAddress) external nonReentrant onlyOwner {
        if (tokenAddress == address(0)) {
            // Transfer native tokens
            (bool sent, bytes memory data) = msg.sender.call{
                value: address(this).balance
            }("");

            if (!sent) revert TransferFailed(address(0), address(this).balance);
        } else {
            IERC20Upgradeable(tokenAddress).safeTransfer(
                msg.sender,
                IERC20Upgradeable(tokenAddress).balanceOf(address(this))
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
        revert CannotRenounceOwnership();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function invalidateNonce(uint64 nonce, bytes memory signature) external {
        // Check if the nonce is valid

        address signer = validateCancelNonce(nonce, signature);

        if (!isApprover(signer)) {
            revert OnlyApprover();
        }

        // Invalidate the nonce
        packPayoutNonce(nonce);
    }
}