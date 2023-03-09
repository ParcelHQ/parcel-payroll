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
        address indexed safeAddress,
        address indexed proxy,
        address indexed implementation
    );

    constructor(address _logic) Ownable2Step() {
        logic = _logic;
        admin = msg.sender;
    }

    function onboard(
        bytes32 salt,
        address[] calldata _approvers,
        uint128 approvalsRequired
    ) public returns (address) {
        require(getParcelAddress[msg.sender] == address(0), "CS020");

        bytes memory _data = abi.encodeCall(
            OrganizerInterface.initialize,
            (_approvers, approvalsRequired)
        );

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy{
            salt: salt
        }(logic, msg.sender, _data);

        OrganizerInterface(address(proxy)).transferOwnership(msg.sender);

        getParcelAddress[msg.sender] = address(proxy);
        emit OrgOnboarded(msg.sender, address(proxy), logic);
        return address(proxy);
    }

    function computeAddress(
        bytes32 salt,
        address[] calldata _approvers,
        uint128 approvalsRequired
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
                                    abi.encode(logic, msg.sender, _data)
                                )
                            )
                        )
                    )
                )
            )
        );

        return predictedAddress;
    }
}
