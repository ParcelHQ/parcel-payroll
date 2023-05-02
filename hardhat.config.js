require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    // Solidity Compiler settings

    etherscan: {
        apiKey: {
            goerli: process.env.ETHERSCAN_API_KEY,
        },
    },

    networks: {
        hardhat: {
            forking: {
                url: process.env.TENDERLY_FORKING_HARDHAT,
            },
            allowUnlimitedContractSize: true,
        },
        goerli: {
            url: process.env.GOERLI_RPC,
            accounts: process.env.MNEMONIC
                ? { mnemonic: process.env.MNEMONIC }
                : [],
        },
    },

    solidity: {
        version: "0.8.17",
        settings: {
            optimizer: {
                enabled: true,
                runs: 100,
            },
        },
    },

    // Gas Reporter
    gasReporter: {
        enabled: true,
        currency: "ETH",
        gasPrice: 21,
    },
};
