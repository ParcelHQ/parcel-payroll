// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers } = require("hardhat");

async function main() {
    // Hardhat always runs the compile task when running scripts through it.
    // If this runs in a standalone fashion you may want to call compile manually
    // to make sure everything is compiled
    // await run("compile");
    // We get the contract to deploy

    const [, parcelDevOperator] = await ethers.getSigners();
    console.log(parcelDevOperator.address);
    const ProxyFactory = await ethers.getContractFactory("ParcelPayroll");

    //   Organizer Contract deployed on Goerli: 0x5D73496c3F35A0b0CDC2B5cDf34b565eE42CfEed
    const Proxy = await ProxyFactory.deploy(
        "0x5D73496c3F35A0b0CDC2B5cDf34b565eE42CfEed",
        "0x",
        parcelDevOperator.address
    );

    await Proxy.deployed();
    console.log("Proxy deployed to: ", Proxy.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
