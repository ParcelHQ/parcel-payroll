// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

// Errors
error InvalidImplementationProvided(address implementation);

/**
 * @title AddressRegistry
 * @author Krishna Kant Sharma - <krishna@parcel.money>
 * @notice - This contract is used to store the whitelisted implementations of the Parcel Payroll contract. Only whitelisted implementations can be used to deploy the Parcel Payroll contract.
 * @dev - This contract is owned by the Parcel. Only the owner can add/remove whitelisted implementations.
 */
contract AddressRegistry is Ownable2Step {
    mapping(address => bool) internal parcelWhitelistedImplementation;

    event ImplementationWhitelisted(
        address indexed implementation,
        bool isActive
    );

    constructor() Ownable2Step() {}

    function setImplementationWhitelist(
        address _implementation,
        bool isActive
    ) external onlyOwner {
        if (
            _implementation == address(0) ||
            _implementation == address(this) ||
            _implementation == owner()
        ) revert InvalidImplementationProvided(_implementation);

        parcelWhitelistedImplementation[_implementation] = isActive;
        emit ImplementationWhitelisted(_implementation, isActive);
    }

    function isWhitelisted(
        address _implementation
    ) external view returns (bool) {
        return parcelWhitelistedImplementation[_implementation];
    }
}
