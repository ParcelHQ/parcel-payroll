// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

interface IAddressRegistry {
    function isWhitelisted(
        address _implementation
    ) external view returns (bool);
}

contract AddressRegistry is Ownable2Step {
    address[] public parcelWhitelistedImplementation;

    constructor() Ownable2Step() {}

    function addNewImplementation(address _implementation) external onlyOwner {
        parcelWhitelistedImplementation.push(_implementation);
    }

    function isWhitelisted(address _implementation) public view returns (bool) {
        for (uint256 i = 0; i < parcelWhitelistedImplementation.length; i++) {
            if (parcelWhitelistedImplementation[i] == _implementation) {
                return true;
            }
        }
        return false;
    }
}
