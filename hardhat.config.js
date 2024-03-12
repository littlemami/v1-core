require("@nomiclabs/hardhat-waffle");
require("@nomicfoundation/hardhat-verify");
require("dotenv").config();
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.22",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    arb: {
      url: process.env.ARB_URL || "",
      accounts: [
        process.env.PRIVATE_KEY ||
          "1234567890123456789012345678901234567890123456789012345678901234",
      ],
    },
    goerli: {
      url: process.env.GOERLI_URL || "",
      accounts: [
        process.env.PRIVATE_KEY ||
          "1234567890123456789012345678901234567890123456789012345678901234",
      ],
    },
    mainnet: {
      url: process.env.MAINNET_URL || "",
      accounts: [
        process.env.PRIVATE_KEY ||
          "1234567890123456789012345678901234567890123456789012345678901234",
      ],
    },
    sep: {
      url: process.env.SEP_URL || "",
      accounts: [
        process.env.PRIVATE_KEY ||
          "1234567890123456789012345678901234567890123456789012345678901234",
      ],
    },
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.MAINNET_VERIFY_KEY || "",
      arbitrumOne: process.env.ARB_VERIFY_KEY || "",
    },
  },
};
