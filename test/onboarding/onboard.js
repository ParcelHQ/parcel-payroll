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
      organizer = await Organizer.deploy(
        masterOperator.address,
        ALLOWANCE_MODULE
      );
      await organizer.connect(multisig).deployed();
    });

    it("Should Onboard A Multisig Organisation", async function () {
      const [multisig, operator_1, operator_2, operator_3] = signers;

      // onboard a dao
      await organizer
        .connect(multisig)
        .onboard(
          [operator_1.address, operator_2.address, operator_3.address],
          threshold
        );

      // verify is dao is onboarded
      expect(await organizer.isOrgOnboarded(multisig.address)).to.equal(true);
    });

    it("Should Offboard A Multisig Organisation", async function () {
      const [multisig, operator_1, operator_2, operator_3] = signers;

      // onboard a dao
      await organizer.connect(multisig).offboard(multisig.address);

      // verify is dao is onboarded
      expect(await organizer.isOrgOnboarded(multisig.address)).to.equal(false);
    });
  });
});