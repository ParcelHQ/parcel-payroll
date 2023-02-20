require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");
require("dotenv").config();
const tenderly = require("@tenderly/hardhat-tenderly");
tenderly.setup({
    automaticVerifications: true,
});

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    // Solidity Compiler settings

    etherscan: {
        apiKey: {
            rinkeby: "C65HXF26NWE1WBFY1HURCT4JS8ZI7A4ZZE",
            goerli: "WEQM48QVPQUPMV1EG2UKDCQJ4S52IYEB5E",
        },
    },

    // networks: {
    //   mainnet: {
    //     forking: {
    //       url: "https://eth-mainnet.g.alchemy.com/v2/62V7EBvEFRA6DT_0RnOdq1c3ZH997ldQ",
    //     },
    //   },

    //   goerli: {
    //     forking: {
    //       url: "https://eth-goerli.g.alchemy.com/v2/MT0pDHBrQ7J8fDTEPdPXcWD-JyAQbH0w",
    //     },
    //   },
    // },

    solidity: {
        version: "0.8.9",
        settings: {
            optimizer: {
                enabled: true,
                runs: 100,
            },
        },
    },

    networks: {
        goerli: {
            url: `https://goerli.infura.io/v3/a610e824d6bc4bef94728de6b76a098f`,
            accounts: [
                process.env.PRIVATE_KEYS_1,
                process.env.PRIVATE_KEYS_2,
                process.env.PRIVATE_KEYS_3,
                process.env.PRIVATE_KEYS_4,
                process.env.PRIVATE_KEYS_5,
                process.env.PRIVATE_KEYS_6,
                process.env.PRIVATE_KEYS_7,
                process.env.PRIVATE_KEYS_8,
            ],
            chainId: 5,
        },
    },

    // Gas Reporter
    gasReporter: {
        enabled: true,
        currency: "ETH",
        gasPrice: 21,
    },
};
