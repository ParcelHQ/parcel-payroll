const { expect } = require("chai");
const { ALLOWANCE_MODULE } = require("../../utils/constant");
require("@nomiclabs/hardhat-ethers");

describe("Organizer Contract", () => {
  describe("Onboarding Process", function () {
    let organizer;
    let signers;
    const threshold = 2;

    it("fetch signers", async function () {
      signers = await ethers.getSigners();
    });

    it("deploy", async function () {
      const [multisig, operator_1, operator_2, operator_3, masterOperator] =
        signers;
      const Organizer = await hre.ethers.getContractFactory("Organizer");
      organizer = await Organizer.deploy(
        masterOperator.address,
        ALLOWANCE_MODULE
      );
      await organizer.connect(multisig).deployed();

      // onboard a dao
      await organizer
        .connect(multisig)
        .onboard(
          [operator_1.address, operator_2.address, operator_3.address],
          threshold
        );
    });

    it("Approves Metadata Should be Valid After Onboarding", async function () {
      const [multisig, operator_1, operator_2, operator_3] = signers;
      // Checking the Approval Counts
      expect(await organizer.getApproverCount(multisig.address)).to.equal(3);

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

    it("Should Modify The Operators, and New Threshold", async function () {
      const [
        multisig,
        operator_1,
        operator_2,
        operator_3,
        operator_4,
        operator_5,
      ] = signers;

      await organizer.modifyApprovers(
        multisig.address,
        [operator_4.address, operator_5.address],
        [operator_1.address],
        3
      );

      // Checking the Approval Counts
      expect(await organizer.getApproverCount(multisig.address)).to.equal(4);

      // Verifying Threshold
      expect(await organizer.getThreshold(multisig.address)).to.equal(3);

      const approvers = await organizer.getApprovers(multisig.address);

      // Verifying Approver Addresses
      expect(approvers).not.to.include(operator_1.address);
      expect(approvers).to.include(operator_2.address);
      expect(approvers).to.include(operator_3.address);
      expect(approvers).to.include(operator_4.address);
      expect(approvers).to.include(operator_5.address);
    });

    it("Should not Modify if Safe Address is not Onboarded", async function () {
      const [
        multisig,
        operator_1,
        operator_2,
        operator_3,
        operator_4,
        operator_5,
        multisig_2,
      ] = signers;

      expect(
        organizer.modifyApprovers(
          multisig_2.address,
          [operator_4.address, operator_5.address],
          [operator_1.address],
          3
        )
      ).to.be.revertedWith("CS009");
    });
  });
});
