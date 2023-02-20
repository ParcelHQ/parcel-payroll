const { expect } = require("chai");
const { ALLOWANCE_MODULE } = require("../../utils/constant");
require("@nomiclabs/hardhat-ethers");

describe("ApprovalManager Contract", () => {
    describe("Approver Manager", function () {
        let organizer;
        let signers;
        const threshold = 2;
        const SENTINEL_ADDRESS = "0x0000000000000000000000000000000000000001";
        const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000";

        it("fetch signers", async function () {
            signers = await ethers.getSigners();
        });

        it("deploy", async function () {
            const [
                multisig,
                operator_1,
                operator_2,
                operator_3,
                masterOperator,
            ] = signers;
            const Organizer = await hre.ethers.getContractFactory("Organizer");
            organizer = await Organizer.deploy(ALLOWANCE_MODULE);
            await organizer.connect(multisig).deployed();

            // onboard a dao
            await organizer
                .connect(multisig)
                .onboard(
                    [
                        operator_1.address,
                        operator_2.address,
                        operator_3.address,
                    ],
                    threshold
                );
        });

        it("Approves Metadata Should be Valid After Onboarding", async function () {
            const [multisig, operator_1, operator_2, operator_3] = signers;
            // Checking the Approval Counts
            expect(await organizer.getApproverCount(multisig.address)).to.equal(
                3
            );

            // Verifying Threshold
            expect(await organizer.getThreshold(multisig.address)).to.equal(
                threshold
            );

            const approvers = await organizer.getApprovers(multisig.address);

            // Verifying Approver Addresses
            expect(approvers).to.include(operator_1.address);
            expect(approvers).to.include(operator_2.address);
            expect(approvers).to.include(operator_3.address);

            // Verifying Approvers Length
            expect(approvers.length).to.equals(3);
        });

        it("Should add the approver with threshold", async function () {
            const [
                multisig,
                operator_1,
                operator_2,
                operator_3,
                operator_4,
                operator_5,
            ] = signers;

            await organizer
                .connect(multisig)
                .addApproverWithThreshold(operator_5.address, 3);

            // Checking the Approval Counts
            expect(await organizer.getApproverCount(multisig.address)).to.equal(
                4
            );

            // Verifying Threshold
            expect(await organizer.getThreshold(multisig.address)).to.equal(3);

            const approvers = await organizer.getApprovers(multisig.address);

            // Verifying Approver Addresses
            expect(approvers).to.include(operator_1.address);
            expect(approvers).to.include(operator_2.address);
            expect(approvers).to.include(operator_3.address);
            expect(approvers).to.include(operator_5.address);
        });

        it("Should not add the approver with threshold = 0", async function () {
            const [
                multisig,
                operator_1,
                operator_2,
                operator_3,
                operator_4,
                operator_5,
            ] = signers;

            expect(
                organizer
                    .connect(multisig)
                    .addApproverWithThreshold(operator_4.address, 0)
            ).to.revertedWith("CS015");
        });

        it("Should not add the approver with duplicate address", async function () {
            const [
                multisig,
                operator_1,
                operator_2,
                operator_3,
                operator_4,
                operator_5,
            ] = signers;

            expect(
                organizer
                    .connect(multisig)
                    .addApproverWithThreshold(operator_5.address, 0)
            ).to.revertedWith("CS002");
        });

        it("Should not add the approver if invalid Address is provider", async function () {
            const [
                multisig,
                operator_1,
                operator_2,
                operator_3,
                operator_4,
                operator_5,
            ] = signers;

            expect(
                organizer
                    .connect(multisig)
                    .addApproverWithThreshold(ADDRESS_ZERO, 3)
            ).to.revertedWith("CS003");
        });

        it("Should change the threshold", async function () {
            const [multisig] = signers;

            await organizer.connect(multisig).changeThreshold(1);

            // Verifying Threshold
            expect(await organizer.getThreshold(multisig.address)).to.equal(1);
        });

        it("Should not change the threshold for zero", async function () {
            const [multisig] = signers;

            expect(
                organizer.connect(multisig).changeThreshold(0)
            ).to.revertedWith("CS015");
        });

        it("Should not change the threshold for threshold greater than approver Count", async function () {
            const [multisig] = signers;

            expect(
                organizer.connect(multisig).changeThreshold(7)
            ).to.revertedWith("CS016");
        });

        it("Should remove the approver address", async function () {
            const [
                multisig,
                operator_1,
                operator_2,
                operator_3,
                operator_4,
                operator_5,
            ] = signers;

            await organizer
                .connect(multisig)
                .removeApprover(SENTINEL_ADDRESS, operator_5.address, 2);

            // Checking the Approval Counts
            expect(await organizer.getApproverCount(multisig.address)).to.equal(
                3
            );

            // Verifying Threshold
            expect(await organizer.getThreshold(multisig.address)).to.equal(2);

            const approvers = await organizer.getApprovers(multisig.address);

            // Verifying Approver Addresses
            expect(approvers).to.include(operator_1.address);
            expect(approvers).to.include(operator_2.address);
            expect(approvers).to.include(operator_3.address);
            expect(approvers).not.to.include(operator_5.address);
        });

        it("Should not remove the approver address if invalid pair provided", async function () {
            const [
                multisig,
                operator_1,
                operator_2,
                operator_3,
                operator_4,
                operator_5,
            ] = signers;

            expect(
                organizer
                    .connect(multisig)
                    .removeApprover(operator_1.address, operator_5.address, 2)
            ).to.revertedWith("CS017");
        });

        it("Should swap the approver", async function () {
            const [multisig, operator_1, operator_2, operator_3, operator_4] =
                signers;

            await organizer
                .connect(multisig)
                .swapApprover(
                    SENTINEL_ADDRESS,
                    operator_1.address,
                    operator_4.address
                );

            // Verifying Threshold
            expect(await organizer.getApproverCount(multisig.address)).to.equal(
                3
            );

            const approvers = await organizer.getApprovers(multisig.address);

            // Verifying Approver Addresses
            expect(approvers).to.include(operator_2.address);
            expect(approvers).to.include(operator_3.address);
            expect(approvers).to.include(operator_4.address);
            expect(approvers).not.to.include(operator_1.address);
        });
    });
});
