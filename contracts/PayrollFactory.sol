// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

interface OrganizerInterface {
    function initialize(
        address[] calldata _approvers,
        uint128 approvalsRequired
    ) external;

    function transferOwnership(address newOwner) external;
}

contract ParcelPayrollFactory is Ownable2Step {
    address public immutable admin;
    address public immutable logic;

    mapping(address => address) public getParcelAddress;

    event OrgOnboarded(
        address safeAddress,
        address indexed proxy,
        address indexed implementation,
        bytes initData
    );

    constructor(address _logic) Ownable2Step() {
        logic = _logic;
        admin = msg.sender;
    }

    function onboard(
        address[] calldata _approvers,
        uint128 approvalsRequired
    ) public returns (address) {
        require(getParcelAddress[msg.sender] == address(0), "CS020");

        bytes memory _data = abi.encodeCall(
            OrganizerInterface.initialize,
            (_approvers, approvalsRequired)
        );

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            logic,
            msg.sender,
            _data
        );

        OrganizerInterface(address(proxy)).transferOwnership(msg.sender);

        getParcelAddress[msg.sender] = address(proxy);
        emit OrgOnboarded(msg.sender, address(proxy), logic, _data);
        return address(proxy);
    }
}
