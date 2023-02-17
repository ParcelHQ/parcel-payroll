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
    const [address1] = await ethers.getSigners();
    const ProxyFactory = await ethers.getContractFactory("Proxy");

    //   Organizer Contract deployed on Goerli: 0xC4b5862e55595389C99D78CEF5b0B95d147A22e3
    const Proxy = await ProxyFactory.deploy(
        "0xE986c310094b23399D55B832BCC33E2849336a4e"
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
