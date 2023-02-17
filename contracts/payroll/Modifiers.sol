//contracts/Organizer.sol
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./Validators.sol";

/// @title Modifiers for Organizer Contract
abstract contract Modifiers is Validators {
    //
    //  Modifiers
    //

    /**
     * @dev Check if the Org is onboarded
     * @param _safeAddress Address of the Org
     */
    modifier onlyOnboarded(address _safeAddress) {
        require(isOrgOnboarded(_safeAddress), "CS009");
        _;
    }

    /**
     * @dev Check if the sender is the multisig
     * @param _safeAddress Address of the Org
     */
    modifier onlyMultisig(address _safeAddress) {
        require(msg.sender == _safeAddress, "CS010");
        _;
    }
}
