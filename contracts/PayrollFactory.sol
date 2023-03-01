// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract ParcelPayrollFactory is Initializable {
    address public admin;

    event ProxyDeployed(
        address indexed proxy,
        address indexed implementation,
        bytes initData
    );

    constructor() {
        admin = msg.sender;
    }

    function deploy(
        address _logic,
        bytes memory _data
    ) public returns (address) {
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            _logic,
            msg.sender,
            _data
        );
        emit ProxyDeployed(address(proxy), _logic, _data);
        return address(proxy);
    }
}
