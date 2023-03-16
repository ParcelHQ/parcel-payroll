// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
    const SafeERC20Upgradeable = await hre.ethers.getContractFactory(
        "SafeERC20Upgradeable"
    );
    const safeERC20Library = await SafeERC20Upgradeable.deploy();

    await safeERC20Library.deployed();

    console.log(
        `SafeERC20Upgradeable is Deployed to ${safeERC20Library.address}`
    );

    // Note: We are using the same address as the one used in the ParcelPayrollFactory
    // Deployed Goerli Address : 0x1dcEE354125E0C8f8e0272DA87747bF23990B6b7
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
