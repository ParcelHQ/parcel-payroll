const { expect } = require("chai");
const { ALLOWANCE_MODULE } = require("../../utils/constant");

describe("Organizer Contract", () => {
    describe("Onboarding Process", function () {
        let organizer;
        let signers;
        const threshold = 2;

        it("fetch signers", async function () {
            signers = await ethers.getSigners();
        });

        it("deploy", async function () {
            const [multisig, __, ___, ____, masterOperator] = signers;
            const Organizer = await hre.ethers.getContractFactory("Organizer");
            organizer = await Organizer.deploy(ALLOWANCE_MODULE);
            await organizer.connect(multisig).deployed();
        });

        it("Should Onboard A Multisig Organisation", async function () {
            const [multisig, operator_1, operator_2, operator_3] = signers;

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

            const dao = await organizer.orgs(multisig.address);

            // verify is dao is onboarded
            expect(dao.approverCount).to.greaterThan(0);
        });

        it("Should Not Offboard A Multisig Organisation If Transaction Not Send By Multisig", async function () {
            const [multisig, operator_1, operator_2, operator_3] = signers;

            // verify is dao is offboarded
            expect(organizer.connect(operator_1).offboard()).to.rejectedWith(
                "CS010"
            );
        });

        it("Should Offboard A Multisig Organisation", async function () {
            const [multisig, operator_1, operator_2, operator_3] = signers;

            // onboard a dao
            await organizer.connect(multisig).offboard();

            const dao = await organizer.orgs(multisig.address);

            // verify is dao is offboarded
            expect(dao.approverCount).to.equal(0);
        });

        it("Should Not be Able to Reannounce Ownership", async function () {
            const [multisig, operator_1, operator_2, operator_3] = signers;

            // onboard a dao
            expect(
                organizer.connect(multisig).renounceOwnership()
            ).to.revertedWith("Ownable: cannot renounce ownership");
        });

        it("Should be able to pause the Contract", async function () {
            const [multisig, operator_1, operator_2, operator_3] = signers;

            // onboard a dao

            await organizer.connect(multisig).pause();

            const isPaused = await organizer.paused();
            expect(isPaused).to.equals(true);

            expect(
                organizer.connect(operator_1).onboard([operator_1.address], 1)
            ).to.revertedWith("Pausable: paused");
        });

        it("Should be able to unpause the Contract", async function () {
            const [multisig, operator_1, operator_2, operator_3] = signers;

            // onboard a dao

            await organizer.connect(multisig).unpause();

            const isPaused = await organizer.paused();
            expect(isPaused).to.equals(false);
        });

        it("Only Owner be able to pause the Contract", async function () {
            const [multisig, operator_1, operator_2, operator_3] = signers;

            // onboard a dao

            expect(organizer.connect(operator_1).pause()).to.revertedWith(
                "Ownable: caller is not the owner"
            );
        });
    });
});
