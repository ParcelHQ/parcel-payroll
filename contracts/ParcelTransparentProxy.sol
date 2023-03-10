// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "./registry/AddressRegistry.sol";

contract ParcelTransparentProxy is TransparentUpgradeableProxy {
    address immutable addressRegistery;

    constructor(
        address logic,
        address admin,
        bytes memory data,
        address _addressRegistery
    ) TransparentUpgradeableProxy(logic, admin, data) {
        addressRegistery = _addressRegistery;
    }

    function upgradeTo(address newImplementation) external override ifAdmin {
        require(
            IAddressRegistry(addressRegistery).isWhitelisted(newImplementation),
            "Not whitelisted"
        );

        _upgradeToAndCall(newImplementation, bytes(""), false);
    }

    function upgradeToAndCall(
        address newImplementation,
        bytes memory data
    ) external payable override ifAdmin {
        require(
            IAddressRegistry(addressRegistery).isWhitelisted(newImplementation),
            "Not whitelisted"
        );

        _upgradeToAndCall(newImplementation, data, false);
    }
}
