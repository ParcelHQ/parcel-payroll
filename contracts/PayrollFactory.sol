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
    address public immutable logic;

    event LogicAddressChanged(
        address indexed oldLogicAddress,
        address indexed newLogicAddress
    );

    mapping(address => address) public getParcelAddress;

    event OrgOnboarded(
        address safeAddress,
        address indexed proxy,
        address indexed implementation,
        bytes initData
    );

    constructor(address _logic) Ownable2Step() {
        logic = _logic;
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
        require(msg.sender == safeAddress, "CS010");

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

        OrganizerInterface(address(proxy)).transferOwnership(safeAddress);

        require(address(proxy) == predictedAddress);

        getParcelAddress[safeAddress] = address(proxy);
        emit OrgOnboarded(safeAddress, address(proxy), predictedAddress, _data);
    }

    function setNewImplementationAddress(address _logic) public onlyOwner {
        require(_logic != address(0), "CS003");
        require(_logic != logic, "CS019");
        emit LogicAddressChanged(logic, _logic);
        logic = _logic;
    }
}
