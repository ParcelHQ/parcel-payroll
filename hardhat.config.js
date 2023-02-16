require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");
const tdly = require("@tenderly/hardhat-tenderly");
tdly.setup();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  // Solidity Compiler settings

  etherscan: {
    apiKey: {
      rinkeby: "C65HXF26NWE1WBFY1HURCT4JS8ZI7A4ZZE",
      goerli: "WEQM48QVPQUPMV1EG2UKDCQJ4S52IYEB5E",
    },
  },

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

  networks: {
    goerli: {
      url: `https://goerli.infura.io/v3/a610e824d6bc4bef94728de6b76a098f`,
      accounts: [
        "ecbc1c5fcb582c701a378ec77295d96198a231cbe01863717c9a38977c35504e",
        "426ca860238d5414b59d9588cb8e85b2aca94bf20a025c175746fa8c14767725",
        "ea4d0bb4bf3c322a8d761ddee6b7ed91b6d1ba379359d27526bdec51e6f83c65",
        "a2d67ebc6a1b1959b0bb4f0ad6c72463c713cfc02b6ba4dce4c15199b79aaf0e",
        "e371fb600be64ab4b0a349de5a54e05e8376a2bfc1eeffc6e59b3968ce27c110",
        "b89750956644c7cffeedcf9d6f4d6113fa3066f07f39308f7c519739c09edec0",
        "ddc83d9ad891ef7fda0c0b9227f3731e6018df8b957dd2af88226db0a26db4c6",
        "8d15969d3724323e490c9193721567f133bb1afedfd21968600f3c78e8ac3f8d",
        "46c071c1951a69a3bfad843d854d62131b1d414726280329e56d92fbca26cb30",
      ],
      chainId: 5,
    },
  },
};

// Tenderly: OGUGlHgN6ZbEt331T-0q3Ze6JGyUztX6
