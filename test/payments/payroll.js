const { expect } = require("chai");
const { ethers } = require("hardhat");
const { ALLOWANCE_MODULE } = require("../../utils/constant");

describe("PayrollManager Contract", () => {
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
      domainData = {
        chainId: 31337,
        verifyingContract: organizer.address,
      };
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

    it("validatePayouts, Should Validate the Payout", async function () {
      const [multisig, operator_1, operator_2, operator_3] = signers;

      // onboard a dao
      await organizer
        .connect(multisig)
        .onboard(
          [operator_1.address, operator_2.address, operator_3.address],
          threshold
        );

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

      const operator1Sign = await operator_1._signTypedData(
        domainData,
        {
          PayrollTx: PayrollTx,
        },
        { rootHash: encodedHash }
      );

      const validatePayoutResponse = await organizer
        .connect(multisig)
        .validatePayouts(multisig.address, [encodedHash], [operator1Sign]);

      const approvedNode = await organizer.approvedNodes(encodedHash);
      expect(approvedNode).to.equal(true);
    });
  });
});
