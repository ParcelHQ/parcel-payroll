const { expect } = require("chai");
const { ethers } = require("hardhat");
const { default: MerkleTree } = require("merkletreejs");
const { ALLOWANCE_MODULE } = require("../../utils/constant");

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
            const [multisig, __, ___, ____, masterOperator] = signers;
            const Organizer = await hre.ethers.getContractFactory("Organizer");
            organizer = await Organizer.deploy(
                masterOperator.address,
                ALLOWANCE_MODULE
            );
            await organizer.connect(multisig).deployed();
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

        it.skip("Should execute the payroll if correct data is passed", async function () {
            const [multisig, operator1, operator2, operator3, masterOperator] =
                signers;

            await organizer
                .connect("0x4789a8423004192D55dCDD81fCbA47dA47D290aD")
                .onboard(
                    [operator1.address, operator2.address, operator3.address],
                    threshold
                );

            // verify is dao is onboarded
            expect(await organizer.isOrgOnboarded(multisig.address)).to.equal(
                true
            );
            const payout_1 = {
                to: "0x4789a8423004192D55dCDD81fCbA47dA47D290aD",
                tokenAddress: "0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C",
                amount: 100,
                payoutNonce: 20,
            };
            const payout_2 = {
                to: "0x4789a8423004192D55dCDD81fCbA47dA47D290aD",
                tokenAddress: "0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C",
                amount: 100,
                payoutNonce: 21,
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

            const transaction = await organizer.bulkExecution(
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
            console.log(transaction);
        });
    });
});
