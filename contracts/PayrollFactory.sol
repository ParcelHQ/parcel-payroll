// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./ParcelTransparentProxy.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

interface IOrganizer {
    function initialize(
        address[] calldata _approvers,
        uint128 approvalsRequired
    ) external;

    function transferOwnership(address newOwner) external;
}

contract ParcelPayrollFactory is Ownable2Step {
    address public logic;
    address public immutable addressRegistry;
    bytes proxyCreationCode;

    event LogicAddressChanged(
        address indexed oldLogicAddress,
        address indexed newLogicAddress
    );

    mapping(address => address) public parcelAddress;

    event OrgOnboarded(
        address safeAddress,
        address indexed proxy,
        address indexed implementation,
        bytes initData
    );

    constructor(address _logic, address _addressRegistry) Ownable2Step() {
        require(address(_logic) != address(0), "CS001");
        require(address(_addressRegistry) != address(0), "CS001");

        logic = _logic;
        addressRegistry = _addressRegistry;
        proxyCreationCode = type(ParcelTransparentProxy).creationCode;
    }

    function computeAddress(
        bytes32 salt,
        address[] calldata _approvers,
        uint128 approvalsRequired,
        address safeAddress
    ) public view returns (address) {
        bytes memory _data = abi.encodeCall(
            IOrganizer.initialize,
            (_approvers, approvalsRequired)
        );

        address predictedAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            keccak256(
                                abi.encodePacked(
                                    proxyCreationCode,
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
        uint128 approvalsRequired
    ) public {
        require(parcelAddress[msg.sender] == address(0), "CS020");

        bytes memory _data = abi.encodeCall(
            IOrganizer.initialize,
            (_approvers, approvalsRequired)
        );

        address predictedAddress = computeAddress(
            salt,
            _approvers,
            approvalsRequired,
            msg.sender
        );

        ParcelTransparentProxy proxy = new ParcelTransparentProxy{salt: salt}(
            logic,
            msg.sender,
            _data,
            addressRegistry
        );

        IOrganizer(address(proxy)).transferOwnership(msg.sender);

        require(address(proxy) == predictedAddress);

        parcelAddress[msg.sender] = address(proxy);
        emit OrgOnboarded(msg.sender, address(proxy), predictedAddress, _data);
    }

    function setNewImplementationAddress(address _logic) public onlyOwner {
        require(_logic != address(0), "CS003");
        require(_logic != logic, "CS019");
        emit LogicAddressChanged(logic, _logic);
        logic = _logic;
    }
}
