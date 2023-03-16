// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./payroll/ApproverManager.sol";
import "./payroll/PayrollManager.sol";

// Errors
error CannotRenounceOwnership();
error SweepFailed(address tokenAddress, uint256 amount);

/**
 * @title ParcelPayroll
 * @dev ParcelPayroll is a secure and decentralized smart contract designed to help organizations pay their contributors with ease and efficiency. The contract utilizes a dedicated approval team, removing the reliance on the organization's multisig, which helps to streamline the payment process and ensure secure payments.
 *
 * One of the key features of ParcelPayroll is its ability to improve approver coordination. Approvers can approve payouts in non-aligned batches, meaning they don't all need to approve the same payouts at the same time. This feature saves time and resources for the organization, as approvers can approve payouts when they are available, rather than being constrained by a strict schedule.
 *
 * With ParcelPayroll, organizations can automate their payment processes, reducing the risk of errors and increasing efficiency. The contract's decentralized architecture ensures that all transactions are transparent and auditable, adding an extra layer of security to the payment process.
 *
 * @author Sriram Kasyap Meduri - <sriram@parcel.money>
 * @author Krishna Kant Sharma - <krishna@parcel.money>
 */

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

        _cachedDomainSeparator = _buildDomainSeparator(address(this));
        _cachedThis = address(this);

        setupApprovers(_approvers, approvalsRequired);
        emit OrgSetup(msg.sender, _approvers, approvalsRequired);
    }

    /**
     * @dev Sweep the contract balance
     * @param tokenAddress - Address of the token to sweep
     */
    function sweep(address tokenAddress) external nonReentrant {
        if (tokenAddress == address(0)) {
            // Transfer native tokens
            (bool sent, bytes memory data) = msg.sender.call{
                value: address(this).balance
            }("");

            if (!sent) revert SweepFailed(address(0), address(this).balance);
        } else {
            try
                IERC20Upgradeable(tokenAddress).safeTransfer(
                    msg.sender,
                    IERC20Upgradeable(tokenAddress).balanceOf(address(this))
                )
            {
                // Transfer ERC20 tokens
            } catch {
                revert SweepFailed(
                    tokenAddress,
                    IERC20Upgradeable(tokenAddress).balanceOf(address(this))
                );
            }
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
