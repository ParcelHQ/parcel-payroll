const { expect } = require("chai");
const { ethers } = require("hardhat");
const { default: MerkleTree } = require("merkletreejs");
const { ALLOWANCE_MODULE } = require("../../utils/constant");
const GnosisSafe = require("../../utils/GnosisSafe.json");
const AllowanceModule = require("../../utils/AllowanceModule.json");

describe("Payroll Contract", () => {
    describe("Payroll Execution Process", function () {
        let organizer;
        let signers;
        const threshold = 2;

        const PayrollTx = [{ name: "rootHash", type: "bytes32" }];

        let domainData;

        const abiCoder = new ethers.utils.AbiCoder();

        it("fetch signers", async function () {
            signers = await ethers.getSigners();
        });

        it("deploy", async function () {
            const [operator1, operator2] = signers;
            const Organizer = await hre.ethers.getContractFactory("Organizer");
            organizer = await Organizer.connect(operator2).deploy(
                ALLOWANCE_MODULE
            );
            await organizer.deployed();
        });

        it("encodeTransactionData, Should Generate the correct hash", async function () {
            const metadata = {
                to: "0x2fEB7B7B1747f6be086d50A939eb141A2e90A2d7",
                tokenAddress: "0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C",
                amount: ethers.utils.parseEther("0.0001"),
                payoutNonce: 1,
            };

            const encodedHash = await organizer.encodeTransactionData(
                metadata.to,
                metadata.tokenAddress,
                metadata.amount,
                metadata.payoutNonce
            );

            const verifiedHash = await ethers.utils.keccak256(
                abiCoder.encode(
                    ["address", "address", "uint256", "uint64"],
                    [
                        metadata.to,
                        metadata.tokenAddress,
                        metadata.amount,
                        metadata.payoutNonce,
                    ]
                )
            );

            expect(encodedHash).to.equals(verifiedHash);
        });

        it("Should execute the payroll if correct data is passed", async function () {
            const [operator1, operator2] = signers;

            console.log(operator1.address, operator2.address);

            EIP712Domain = [
                { type: "uint256", name: "chainId" },
                { type: "address", name: "verifyingContract" },
            ];

            const types = [
                { type: "address", name: "to" },
                { type: "uint256", name: "value" },
                { type: "bytes", name: "data" },
                { type: "uint8", name: "operation" },
                { type: "uint256", name: "safeTxGas" },
                { type: "uint256", name: "baseGas" },
                { type: "uint256", name: "gasPrice" },
                { type: "address", name: "gasToken" },
                { type: "address", name: "refundReceiver" },
                { type: "uint256", name: "nonce" },
            ];

            const safe = await ethers.getContractAt(
                GnosisSafe,
                "0x4789a8423004192D55dCDD81fCbA47dA47D290aD"
            );

            const allowanceModule = await ethers.getContractAt(
                AllowanceModule,
                ALLOWANCE_MODULE
            );

            const domain = {
                verifyingContract: "0x4789a8423004192D55dCDD81fCbA47dA47D290aD",
                chainId: 31337,
            };
            const transaction = {
                to: organizer.address,
                value: 0,
                data: organizer.interface.encodeFunctionData("onboard", [
                    [operator1.address, operator2.address],
                    2,
                ]),
                operation: 0,
            };

            const nonce = await safe.nonce();

            const message = {
                to: transaction.to,
                value: transaction.value,
                data: transaction.data,
                operation: transaction.operation,
                safeTxGas: 0,
                baseGas: 0,
                gasPrice: 0,
                gasToken: "0x0000000000000000000000000000000000000000",
                refundReceiver: "0x0000000000000000000000000000000000000000",
                nonce: nonce,
            };

            const sigs = await operator1._signTypedData(
                domain,
                {
                    SafeTx: types,
                },
                message
            );

            const onboardTransaciton = await safe.execTransaction(
                transaction.to,
                transaction.value,
                transaction.data,
                transaction.operation,
                0,
                0,
                0,
                "0x0000000000000000000000000000000000000000",
                "0x0000000000000000000000000000000000000000",
                sigs
            );

            await onboardTransaciton.wait();

            const addDelegateTransaction = {
                to: allowanceModule.address,
                value: 0,
                data: allowanceModule.interface.encodeFunctionData(
                    "addDelegate",
                    [organizer.address]
                ),
                operation: 0,
            };

            const addDelegateNonce = await safe.nonce();

            const addDelegateMessage = {
                to: addDelegateTransaction.to,
                value: addDelegateTransaction.value,
                data: addDelegateTransaction.data,
                operation: addDelegateTransaction.operation,
                safeTxGas: 0,
                baseGas: 0,
                gasPrice: 0,
                gasToken: "0x0000000000000000000000000000000000000000",
                refundReceiver: "0x0000000000000000000000000000000000000000",
                nonce: addDelegateNonce,
            };

            const addDelegateSign = await operator1._signTypedData(
                domain,
                {
                    SafeTx: types,
                },
                addDelegateMessage
            );

            const addDelegate = await safe.execTransaction(
                addDelegateTransaction.to,
                addDelegateTransaction.value,
                addDelegateTransaction.data,
                addDelegateTransaction.operation,
                0,
                0,
                0,
                "0x0000000000000000000000000000000000000000",
                "0x0000000000000000000000000000000000000000",
                addDelegateSign
            );

            await addDelegate.wait();

            const setAllowance = {
                to: allowanceModule.address,
                value: 0,
                data: allowanceModule.interface.encodeFunctionData(
                    "setAllowance",
                    [
                        organizer.address,
                        "0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C",
                        100000000,
                        0,
                        0,
                    ]
                ),
                operation: 0,
            };

            const setAllowanceNonce = await safe.nonce();

            const setAllowanceMessage = {
                to: setAllowance.to,
                value: setAllowance.value,
                data: setAllowance.data,
                operation: setAllowance.operation,
                safeTxGas: 0,
                baseGas: 0,
                gasPrice: 0,
                gasToken: "0x0000000000000000000000000000000000000000",
                refundReceiver: "0x0000000000000000000000000000000000000000",
                nonce: setAllowanceNonce,
            };

            const setAllowanceSign = await operator1._signTypedData(
                domain,
                {
                    SafeTx: types,
                },
                setAllowanceMessage
            );

            const setAllowanceTx = await safe.execTransaction(
                setAllowance.to,
                setAllowance.value,
                setAllowance.data,
                setAllowance.operation,
                0,
                0,
                0,
                "0x0000000000000000000000000000000000000000",
                "0x0000000000000000000000000000000000000000",
                setAllowanceSign
            );

            await setAllowanceTx.wait();

            // verify is dao is onboarded

            const dao = await organizer.orgs(safe.address);

            // verify is dao is onboarded
            expect(dao.approverCount).to.greaterThan(0);

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

            const encodedHash_1 = await organizer
                .connect(operator1)
                .encodeTransactionData(
                    payout_1.to,
                    payout_1.tokenAddress,
                    payout_1.amount,
                    payout_1.payoutNonce
                );
            console.log(encodedHash_1);
            const encodedHash_2 = await organizer
                .connect(operator1)
                .encodeTransactionData(
                    payout_2.to,
                    payout_2.tokenAddress,
                    payout_2.amount,
                    payout_2.payoutNonce
                );

            const leaves_1 = [encodedHash_1, encodedHash_2];

            const leaves_2 = [encodedHash_1, encodedHash_2];

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
                chainId: 31337,
                verifyingContract: organizer.address,
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

            const payouts = [payout_1, payout_2];

            let tos = [];
            let tokenAddresses = [];
            let amounts = [];
            let payoutNonces = [];
            let proofs = [];

            for (let i = 0; i < payouts.length; i++) {
                const encodedHash = await organizer.encodeTransactionData(
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

            console.log(organizer.address, "Address");

            const execPayroll = await organizer.executePayroll(
                "0x4789a8423004192D55dCDD81fCbA47dA47D290aD",
                tos,
                tokenAddresses,
                amounts,
                payoutNonces,
                proofs,
                Object.values(rootsObject),
                Object.values(SignatureObject),
                ["0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C"],
                [1000],
                { gasLimit: 9000000 }
            );

            const nonce_1 = await organizer.getPayoutNonce(safe.address, 1);
            const nonce_2 = await organizer.getPayoutNonce(safe.address, 2);
            expect(nonce_1).to.equals(true);
            expect(nonce_2).to.equals(true);
        });
    });
});
