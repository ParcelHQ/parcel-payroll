require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    // Solidity Compiler settings

    etherscan: {
        apiKey: {
            rinkeby: "C65HXF26NWE1WBFY1HURCT4JS8ZI7A4ZZE",
            goerli: "WEQM48QVPQUPMV1EG2UKDCQJ4S52IYEB5E",
        },
    },

    networks: {
        goerli: {
            url: `https://goerli.infura.io/v3/a610e824d6bc4bef94728de6b76a098f`,
            accounts: [
                "ecbc1c5fcb582c701a378ec77295d96198a231cbe01863717c9a38977c35504e",
                "ea4d0bb4bf3c322a8d761ddee6b7ed91b6d1ba379359d27526bdec51e6f83c65",
            ],
            chainId: 5,
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

    // Gas Reporter
    gasReporter: {
        enabled: true,
        currency: "ETH",
        gasPrice: 21,
    },
};
