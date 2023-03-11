// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ParcelTransparentProxy.sol";

interface OrganizerInterface {
    function initialize(
        address[] calldata _approvers,
        uint128 approvalsRequired
    ) external;

    function transferOwnership(address newOwner) external;
}

contract ParcelPayrollFactory {
    address public immutable logic;
    address public immutable addressRegistry;

    mapping(address => address) public getParcelAddress;

    event OrgOnboarded(
        address safeAddress,
        address indexed proxy,
        address indexed implementation,
        bytes initData
    );

    constructor(address _logic, address _addressRegistry) {
        logic = _logic;
        addressRegistry = _addressRegistry;
    }

    function computeAddress(
        bytes32 salt,
        address[] calldata _approvers,
        uint128 approvalsRequired,
        address safeAddress
    ) public view returns (address) {
        bytes memory _data = abi.encodeCall(
            OrganizerInterface.initialize,
            (_approvers, approvalsRequired)
        );

        address predictedAddress = address(
            uint160(
                uint(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            keccak256(
                                abi.encodePacked(
                                    type(ParcelTransparentProxy).creationCode,
                                    abi.encode(
                                        logic,
                                        safeAddress,
                                        _data,
                                        addressRegistry
                                    )
                                )
                            )
                        )
                    )
                )
            )
        );
        return predictedAddress;
    }

    function onboard(
        bytes32 salt,
        address[] calldata _approvers,
        uint128 approvalsRequired,
        address safeAddress
    ) public {
        require(getParcelAddress[msg.sender] == address(0), "CS020");
        require(msg.sender == safeAddress, "Multisig Only");

        bytes memory _data = abi.encodeCall(
            OrganizerInterface.initialize,
            (_approvers, approvalsRequired)
        );

        address predictedAddress = computeAddress(
            salt,
            _approvers,
            approvalsRequired,
            safeAddress
        );

        ParcelTransparentProxy proxy = new ParcelTransparentProxy{salt: salt}(
            logic,
            safeAddress,
            _data,
            addressRegistry
        );

        OrganizerInterface(address(proxy)).transferOwnership(safeAddress);

        require(address(proxy) == predictedAddress);

        getParcelAddress[safeAddress] = address(proxy);
        emit OrgOnboarded(safeAddress, address(proxy), predictedAddress, _data);
    }
}
