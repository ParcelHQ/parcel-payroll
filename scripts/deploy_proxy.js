// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
    const ParcelTransparentProxy = await hre.ethers.getContractFactory(
        "ParcelTransparentProxy"
    );
    const proxy = await ParcelTransparentProxy.deploy(
        "0x3B09Dbc8CA1eBac0CDe743C3A68c2b2d376Df0fa",
        "0xd97eEe2c1FD746c55B37Ffe93Cf1b0655fC3C397",
        "0x",
        "0xd97eEe2c1FD746c55B37Ffe93Cf1b0655fC3C397"
    );

    await proxy.deployed();

    console.log(`Parcel Proxy is Deployed to ${proxy.address}`);
    // Latest Deployed Factory Address is : 0x32ABb4fB5a1Df789B5Df426f6Fe1cB55Cf20d927
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
