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
