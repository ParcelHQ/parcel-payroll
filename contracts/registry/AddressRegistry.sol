// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

interface IAddressRegistry {
    function isWhitelisted(
        address _implementation
    ) external view returns (bool);
}

contract AddressRegistry is Ownable2Step {
    address internal constant SENTINEL_IMPLEMENTATION = address(0x1);
    mapping(address => address) internal parcelWhitelistedImplementation;
    uint256 internal parcelWhitelistedImplementationCount;

    constructor() Ownable2Step() {}

    function addNewImplementation(address _implementation) external onlyOwner {
        require(
            _implementation != address(0) &&
                _implementation != SENTINEL_IMPLEMENTATION &&
                _implementation != address(this) &&
                _implementation != owner(),
            "CS001"
        );
        // No duplicate approvers allowed.
        require(
            parcelWhitelistedImplementation[_implementation] == address(0),
            "CS001"
        );
        parcelWhitelistedImplementation[
            _implementation
        ] = parcelWhitelistedImplementation[SENTINEL_IMPLEMENTATION];
        parcelWhitelistedImplementation[
            SENTINEL_IMPLEMENTATION
        ] = _implementation;
        parcelWhitelistedImplementationCount++;
    }

    function isWhitelisted(address _implementation) public view returns (bool) {
        return
            _implementation != SENTINEL_IMPLEMENTATION &&
            parcelWhitelistedImplementation[_implementation] != address(0);
    }
}
