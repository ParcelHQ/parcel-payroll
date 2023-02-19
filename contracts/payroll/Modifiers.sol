//contracts/Organizer.sol
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./Storage.sol";

/// @title Modifiers for Organizer Contract
abstract contract Modifiers is Storage {
    //
    //  Modifiers
    //

    /**
     * @dev Check if the Org is onboarded
     * @param _safeAddress Address of the Org
     */
    modifier onlyOnboarded(address _safeAddress) {
        require(orgs[_safeAddress].approverCount > 0, "CS009");
        _;
    }
}
