//contracts/Proxy.sol
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ParcelPayroll is ERC1967Proxy {
    constructor(
        address _logic,
        bytes memory _data,
        address _admin
    ) ERC1967Proxy(_logic, _data) {}

    function _implementation() internal view override returns (address) {
        return _getImplementation();
    }
}
