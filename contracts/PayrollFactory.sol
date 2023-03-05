// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

interface OrganizerInterface {
    function initialize(
        address[] calldata _approvers,
        uint128 approvalsRequired
    ) external;
}

contract ParcelPayrollFactory {
    address public immutable admin;
    address public immutable logic;

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

    function onboard(
        address[] calldata _approvers,
        uint128 approvalsRequired
    ) public returns (address) {
        bytes memory _data = abi.encodeCall(
            OrganizerInterface.initialize,
            (_approvers, approvalsRequired)
        );
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            logic,
            tx.origin,
            _data
        );

        getParcelAddress[msg.sender] = address(proxy);
        emit OrgOnboarded(msg.sender, address(proxy), logic, _data);
        return address(proxy);
    }
}
