const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { default: MerkleTree } = require("merkletreejs");
const ORGANIZER_V1_ABI = require("../utils/Organizer_v1");

function encodeMultiSendData(txs) {
    return "0x" + txs.map((tx) => encodeMetaTransaction(tx)).join("");
}

function encodeMetaTransaction(tx) {
    const data = ethers.utils.arrayify(tx.data);
    const encoded = ethers.utils.solidityPack(
        ["uint8", "address", "uint256", "uint256", "bytes"],
        [tx.operation, tx.to, tx.value, data.length, data]
    );
    return encoded.slice(2);
}

function standardizeMetaTransactionData(tx) {
    const standardizedTxs = {
        ...tx,
        operation: tx.operation ?? 0,
    };
    return standardizedTxs;
}

const MultisendABi = [
    {
        inputs: [
            { internalType: "bytes", name: "transactions", type: "bytes" },
        ],
        name: "multiSend",
        outputs: [],
        stateMutability: "payable",
        type: "function",
    },
];

describe("PayrollManager", function () {
    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.

    let payrollManager;

    describe("Deployment", function () {
        it("Should Deploy the Contract", async function () {
            payrollManager = await ethers.getContractAt(
                ORGANIZER_V1_ABI,
                "0xd13d91Fedd41e4EF02CD816B598838A827f35C78"
            );

            const [operator1, operator2] = await ethers.getSigners();
            console.log(operator1.address);
            const payout_1 = {
                to: "0x4789a8423004192D55dCDD81fCbA47dA47D290aD",
                tokenAddress: "0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C",
                amount: 100,
                payoutNonce: 1,
            };
            const payout_2 = {
                to: "0x4789a8423004192D55dCDD81fCbA47dA47D290aD",
                tokenAddress: "0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C",
                amount: 100,
                payoutNonce: 2,
            };
            const payout_3 = {
                to: "0x4789a8423004192D55dCDD81fCbA47dA47D290aD",
                tokenAddress: "0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C",
                amount: 100,
                payoutNonce: 3,
            };
            const payout_4 = {
                to: "0x4789a8423004192D55dCDD81fCbA47dA47D290aD",
                tokenAddress: "0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C",
                amount: 100,
                payoutNonce: 4,
            };
            const payout_5 = {
                to: "0x4789a8423004192D55dCDD81fCbA47dA47D290aD",
                tokenAddress: "0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C",
                amount: 100,
                payoutNonce: 5,
            };
            const payout_6 = {
                to: "0x4789a8423004192D55dCDD81fCbA47dA47D290aD",
                tokenAddress: "0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C",
                amount: 100,
                payoutNonce: 6,
            };

            const payout_7 = {
                to: "0x4789a8423004192D55dCDD81fCbA47dA47D290aD",
                tokenAddress: "0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C",
                amount: 100,
                payoutNonce: 13,
            };

            const encodedHash_1 = await payrollManager
                .connect(operator1)
                .encodeTransactionData(
                    payout_1.to,
                    payout_1.tokenAddress,
                    payout_1.amount,
                    payout_1.payoutNonce
                );
            console.log(encodedHash_1);
            const encodedHash_2 = await payrollManager
                .connect(operator1)
                .encodeTransactionData(
                    payout_2.to,
                    payout_2.tokenAddress,
                    payout_2.amount,
                    payout_2.payoutNonce
                );
            console.log(encodedHash_2);
            const encodedHash_3 = await payrollManager
                .connect(operator1)
                .encodeTransactionData(
                    payout_3.to,
                    payout_3.tokenAddress,
                    payout_3.amount,
                    payout_3.payoutNonce
                );
            console.log(encodedHash_3);
            const encodedHash_4 = await payrollManager
                .connect(operator1)
                .encodeTransactionData(
                    payout_4.to,
                    payout_4.tokenAddress,
                    payout_4.amount,
                    payout_4.payoutNonce
                );
            console.log(encodedHash_4);
            const encodedHash_5 = await payrollManager
                .connect(operator1)
                .encodeTransactionData(
                    payout_5.to,
                    payout_5.tokenAddress,
                    payout_5.amount,
                    payout_5.payoutNonce
                );

            console.log(encodedHash_5);

            const encodedHash_6 = await payrollManager
                .connect(operator1)
                .encodeTransactionData(
                    payout_6.to,
                    payout_6.tokenAddress,
                    payout_6.amount,
                    payout_6.payoutNonce
                );

            console.log(encodedHash_6);
            const encodedHash_7 = await payrollManager
                .connect(operator1)
                .encodeTransactionData(
                    payout_7.to,
                    payout_7.tokenAddress,
                    payout_7.amount,
                    payout_7.payoutNonce
                );
            console.log(encodedHash_7);

            // Creating Root Hashes Per Approver
            const leaves_1 = [
                encodedHash_1,
                encodedHash_2,
                encodedHash_3,
                encodedHash_4,
                encodedHash_5,
                encodedHash_6,
            ];

            const leaves_2 = [
                encodedHash_1,
                encodedHash_2,
                encodedHash_3,
                encodedHash_4,
                encodedHash_5,
                encodedHash_6,
            ];

            const tree_1 = new MerkleTree(leaves_1, ethers.utils.keccak256, {
                sortPairs: true,
            });

            const tree_2 = new MerkleTree(leaves_2, ethers.utils.keccak256, {
                sortPairs: true,
            });

            const rootsObject = {};
            //  Generating Node Hash
            rootsObject[operator1.address] =
                "0x" + tree_1.getRoot().toString("hex");
            rootsObject[operator2.address] =
                "0x" + tree_2.getRoot().toString("hex");

            // Creating Signatures
            const PayrollTx = [{ name: "rootHash", type: "bytes32" }];

            let domainData = {
                chainId: 5,
                verifyingContract: payrollManager.address,
            };

            const SignatureObject = {};

            SignatureObject[operator1.address] = await operator1._signTypedData(
                domainData,
                {
                    PayrollTx: PayrollTx,
                },
                { rootHash: rootsObject[operator1.address] }
            );

            SignatureObject[operator2.address] = await operator2._signTypedData(
                domainData,
                {
                    PayrollTx: PayrollTx,
                },
                { rootHash: rootsObject[operator2.address] }
            );

            console.log(SignatureObject, "Signature Done");
            //  Validation Transaction

            // const multiSendTransaction = [];
            const sortedOperators = [operator1.address, operator2.address].sort(
                (a, b) => a - b
            );

            console.log({ sortedOperators });
            // const validationTransaction = {
            //     to: payrollManager.address,
            //     value: 0,
            //     data: payrollManager.interface.encodeFunctionData(
            //         "validatePayouts",
            //         [
            //             "0x4789a8423004192D55dCDD81fCbA47dA47D290aD",
            //             sortedOperators.map((a) => rootsObject[a]),
            //             sortedOperators.map((a) => SignatureObject[a]),
            //             ["0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C"],
            //             [1000000],
            //         ]
            //     ),
            //     gasLimit: 9000000,
            // };

            // multiSendTransaction.push(validationTransaction);

            //  Execution transaction

            const payouts = [
                payout_1,
                payout_2,
                payout_3,
                payout_4,
                payout_5,
                payout_6,
            ];

            let tos = [];
            let tokenAddresses = [];
            let amounts = [];
            let payoutNonces = [];
            let proofs = [];

            for (let i = 0; i < payouts.length; i++) {
                const encodedHash = await payrollManager.encodeTransactionData(
                    payouts[i].to,
                    payouts[i].tokenAddress,
                    payouts[i].amount,
                    payouts[i].payoutNonce
                );

                const proof_1 = tree_1.getHexProof(encodedHash);
                const proof_2 = tree_2.getHexProof(encodedHash);

                tos.push(payouts[i].to);
                tokenAddresses.push(payouts[i].tokenAddress);
                amounts.push(payouts[i].amount);
                payoutNonces.push(payouts[i].payoutNonce);

                proofs.push([proof_1, proof_2]);
            }

            console.log(payrollManager.address, "Address");

            const transaction = await payrollManager.bulkExecution(
                "0x4789a8423004192D55dCDD81fCbA47dA47D290aD",
                tos,
                tokenAddresses,
                amounts,
                payoutNonces,
                proofs,
                sortedOperators.map((a) => rootsObject[a]),
                sortedOperators.map((a) => SignatureObject[a]),
                ["0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C"],
                [600],
                { gasLimit: 9000000 }
            );

            console.log(transaction);
            // const multiSendData = encodeMultiSendData(
            //   multiSendTransaction.map(standardizeMetaTransactionData)
            // );

            // const transaction = await payrollManager
            //   .connect(operator1)
            //   .multiSend(multiSendData, { gasLimit: 9000000 });
            // console.log(transaction);
        });
    });
});
