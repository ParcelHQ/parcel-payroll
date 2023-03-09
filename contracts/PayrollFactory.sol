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
                                    type(TransparentUpgradeableProxy)
                                        .creationCode,
                                    abi.encode(logic, safeAddress, _data)
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

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy{
            salt: salt
        }(logic, safeAddress, _data);

        require(address(proxy) == predictedAddress);

        getParcelAddress[safeAddress] = address(proxy);
        emit OrgOnboarded(safeAddress, address(proxy), predictedAddress, _data);
    }
}
