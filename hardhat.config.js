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
            sepolia: process.env.ETHERSCAN_API_KEY,
            base_sepolia: process.env.BASESCAN_API_KEY,
            base: process.env.BASESCAN_API_KEY,
        },
        customChains: [
            {
                network: "base_sepolia",
                chainId: 84532,
                urls: {
                    apiURL: "https://api-sepolia.basescan.org/api",
                    browserURL: "https://sepolia.basescan.org",
                },
            },
            {
                network: "base",
                chainId: 8453,
                urls: {
                    apiURL: "https://api.basescan.org/api",
                    browserURL: "https://basescan.org",
                },
            },
        ],
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
        sepolia: {
            url: process.env.SEPOLIA_RPC,
            accounts: process.env.MNEMONIC
                ? { mnemonic: process.env.MNEMONIC }
                : [],
        },
        base_sepolia: {
            // 84532
            url: process.env.BASE_SEPOLIA_RPC,
            accounts: [process.env.PARCEL_BASE_DEV_PK],
        },
        base: {
            // 8453
            url: process.env.BASE_RPC,
            accounts: [process.env.BASE_PROD_PK],
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
