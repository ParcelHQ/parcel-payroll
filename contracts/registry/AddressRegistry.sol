// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

interface IAddressRegistry {
    function isWhitelisted(
        address _implementation
    ) external view returns (bool);
}

contract AddressRegistry is Ownable2Step {
    mapping(address => bool) internal parcelWhitelistedImplementation;

    constructor() Ownable2Step() {}

    function addNewImplementation(address _implementation) external onlyOwner {
        require(
            _implementation != address(0) &&
                _implementation != address(this) &&
                _implementation != owner(),
            "CS001"
        );

        parcelWhitelistedImplementation[_implementation] = true;
    }

    function isWhitelisted(address _implementation) public view returns (bool) {
        return parcelWhitelistedImplementation[_implementation];
    }
}
