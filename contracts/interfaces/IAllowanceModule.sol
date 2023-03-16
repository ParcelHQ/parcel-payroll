// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IAllowanceModule {
    function executeAllowanceTransfer(
        address safe,
        address token,
        address payable to,
        uint96 amount,
        address paymentToken,
        uint96 payment,
        address delegate,
        bytes memory signature
    ) external;
}
