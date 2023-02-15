//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/index.sol";
import "../utils/BitPacker.sol";

contract GnosisHelper is BitPacker {
     /**
     * @dev Execute transaction from Gnosis Safe
     * @param safeAddress Address of the Gnosis Safe
     * @param tokenAddress Address of the token to send
     * @param amount Amount of tokens to send
     * @param signature Signature of the transaction
     */
    function execTransactionFromGnosis(
        address safeAddress,
        address tokenAddress,
        uint96 amount,
        bytes memory signature
    ) internal {
        AlowanceModule allowance = AlowanceModule(ALLOWANCE_MODULE);

        address payable to = payable(address(this));

        // Execute payout via allowance module
        allowance.executeAllowanceTransfer(
            GnosisSafe(safeAddress),
            tokenAddress,
            to,
            amount,
            0x0000000000000000000000000000000000000000,
            0,
            address(this),
            signature
        );
    }

}