// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract ParcelPayrollFactory {
    address public admin;
    address public logic;

    mapping(address => address) public getParcelAddress;

    event OrgOnboarded(
        address safeAddress,
        address indexed proxy,
        address indexed implementation,
        bytes initData
    );

    constructor(address _logic) {
        logic = _logic;
        admin = msg.sender;
    }

    function onboard(bytes memory _data) public returns (address) {
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            logic,
            msg.sender,
            _data
        );

        getParcelAddress[msg.sender] = address(proxy);
        emit OrgOnboarded(msg.sender, address(proxy), logic, _data);
        return address(proxy);
    }
}
