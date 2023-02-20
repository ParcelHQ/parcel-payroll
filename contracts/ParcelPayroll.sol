//contracts/Proxy.sol
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ParcelPayroll is ERC1967Proxy {
    constructor(
        address _logic,
        bytes memory _data,
        address _admin
    ) ERC1967Proxy(_logic, _data) {
        _changeAdmin(_admin);
    }

    function getimplementation() public view returns (address) {
        return _getImplementation();
    }

    function getAdmin() public view returns (address) {
        return _getAdmin();
    }

    function upgradeTo(address _newImplementation) public {
        require(_getAdmin() == msg.sender, "Only admin can upgrade");
        _upgradeTo(_newImplementation);
    }

    function setAdmin(address _newAdmin) public {
        require(_getAdmin() == msg.sender, "Only admin can change admin");
        _changeAdmin(_newAdmin);
    }
}
