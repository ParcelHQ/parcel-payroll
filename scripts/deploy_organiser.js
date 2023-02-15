// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers } = require("hardhat");
const { ALLOWANCE_MODULE } = require("../utils/constant");

async function main() {
  // Hardhat always runs the compile task when running scripts through it.
  // If this runs in a standalone fashion you may want to call compile manually
  // to make sure everything is compiled
  // await run("compile");
  // We get the contract to deploy

  const [masterOperator] = await ethers.getSigners();
  const OrganizerFactory = await ethers.getContractFactory("Organizer");
  const Organizer = await OrganizerFactory.deploy(
    ALLOWANCE_MODULE,
    masterOperator.getAddress()
  );
  await Organizer.deployed();
  console.log("Organizer deployed to: ", Organizer.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
