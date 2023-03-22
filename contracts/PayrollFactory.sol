// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./ParcelTransparentProxy.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

interface IParcelPayroll {
    function initialize(
        address safeAddress,
        address[] calldata _approvers,
        uint128 approvalsRequired
    ) external;

    function transferOwnership(address newOwner) external;
}

//  Errors
error InvalidLogicAddressProvided(address logicAddress);
error InvalidAddressRegistryProvided(address addressRegistry);
error OrgOnboardedAlready(address orgAddress);
error CannotDeployForOthers();
error ProxyDoesntMatchPrediction(address proxy, address prediction);

/**
 * @title ParcelPayrollFactory - A factory contract to deploy ParcelPayroll contracts.
 * @author Krishna Kant Sharma - <krishna@parcel.money>
 * @author Sriram Kasyap Meduri - <sriram@parcel.money>
 */

contract ParcelPayrollFactory is Ownable2Step {
    address public logic;
    address public immutable addressRegistry;
    bytes proxyCreationCode;

    /**
     * @dev Emitted when the logic address is changed
     * @param oldLogicAddress - The old logic address
     * @param newLogicAddress - The new logic address
     */
    event LogicAddressChanged(
        address indexed oldLogicAddress,
        address indexed newLogicAddress
    );

    /**
     * @dev Mapping of org address to ParcelPayroll contract address
     */
    mapping(address => address) public parcelAddress;

    /**
     * @dev Emitted when a new ParcelPayroll contract is deployed
     * @param safeAddress - The safe address of the org
     * @param proxy -  Address of the ParcelPayroll contract
     * @param implementation - Address of the logic contract
     * @param initData - The data used to initialize the ParcelPayroll contract
     */
    event OrgOnboarded(
        address safeAddress,
        address indexed proxy,
        address indexed implementation,
        bytes initData
    );

    /**
     * @dev Constructor for ParcelPayrollFactory
     * @param _logic - Address of the logic contract
     * @param _addressRegistry - Address of the AddressRegistry contract
     */
    constructor(address _logic, address _addressRegistry) Ownable2Step() {
        if (address(_logic) == address(0))
            revert InvalidLogicAddressProvided(_logic);
        if (address(_addressRegistry) == address(0))
            revert InvalidAddressRegistryProvided(_addressRegistry);

        logic = _logic;
        addressRegistry = _addressRegistry;
        proxyCreationCode = type(ParcelTransparentProxy).creationCode;
    }

    /**
     * @dev Compute / Predict the address of the ParcelPayroll contract to be deployed
     * @param salt - Salt used to compute the address
     * @param _approvers - Array of approver addresses
     * @param approvalsRequired - Number of approvals required for a payout to be executed
     * @param safeAddress - The safe address of the org
     * @return predictedAddress - The predicted address of the ParcelPayroll contract
     */
    function computeAddress(
        bytes32 salt,
        address[] calldata _approvers,
        uint128 approvalsRequired,
        address safeAddress
    ) public view returns (address) {
        bytes memory _data = abi.encodeCall(
            IParcelPayroll.initialize,
            (safeAddress, _approvers, approvalsRequired)
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

    /**
     * @dev Deploy a new ParcelPayroll contract
     * @param salt - Salt used to compute the address
     * @param _approvers - Array of approver addresses
     * @param approvalsRequired - Number of approvals required for a payout to be executed
     */
    function onboard(
        bytes32 salt,
        address[] calldata _approvers,
        uint128 approvalsRequired
    ) public {
        if (parcelAddress[msg.sender] != address(0))
            revert OrgOnboardedAlready(msg.sender);

        bytes memory _data = abi.encodeCall(
            IParcelPayroll.initialize,
            (msg.sender, _approvers, approvalsRequired)
        );

        ParcelTransparentProxy proxy = new ParcelTransparentProxy{salt: salt}(
            logic,
            msg.sender,
            _data,
            addressRegistry
        );

        address proxyAddress = address(proxy);

        parcelAddress[msg.sender] = proxyAddress;
        emit OrgOnboarded(msg.sender, proxyAddress, logic, _data);
    }

    /**
     * @dev Set new Implementation address
     * @param _logic - Address of the new logic contract
     */
    function setNewImplementationAddress(address _logic) public onlyOwner {
        if (_logic == address(0) || _logic == logic)
            revert InvalidLogicAddressProvided(_logic);

        emit LogicAddressChanged(logic, _logic);
        logic = _logic;
    }
}
