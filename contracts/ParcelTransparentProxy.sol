// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "./registry/AddressRegistry.sol";

contract ParcelTransparentProxy is TransparentUpgradeableProxy {
    address immutable addressRegistry;

    constructor(
        address logic,
        address admin,
        bytes memory data,
        address _addressRegistry
    ) TransparentUpgradeableProxy(logic, admin, data) {
        addressRegistry = _addressRegistry;
    }

    function upgradeTo(address newImplementation) external override ifAdmin {
        require(
            IAddressRegistry(addressRegistry).isWhitelisted(newImplementation),
            "Not whitelisted"
        );

        _upgradeToAndCall(newImplementation, bytes(""), false);
    }

    function upgradeToAndCall(
        address newImplementation,
        bytes memory data
    ) external payable override ifAdmin {
        require(
            IAddressRegistry(addressRegistry).isWhitelisted(newImplementation),
            "Not whitelisted"
        );

        _upgradeToAndCall(newImplementation, data, false);
    }
}
