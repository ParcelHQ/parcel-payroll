// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
    const ParcelPayrollFactory = await hre.ethers.getContractFactory(
        "ParcelPayrollFactory"
    );
    const factory = await ParcelPayrollFactory.deploy(
        "SINGLETON_ADDRESS",
        "ADDRESS_REGISTRY_ADDRESS"
    );

    await factory.deployed();

    console.log(`ParcelPayrollFactory is Deployed to ${factory.address}`);
    // Latest Deployed Factory Address is : 0x32ABb4fB5a1Df789B5Df426f6Fe1cB55Cf20d927
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
