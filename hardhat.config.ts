import { task } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import "hardhat-contract-sizer";
import "hardhat-log-remover";
import "hardhat-deploy";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "solidity-coverage";
import "hardhat-gas-reporter";
import exportDeployments from "./scripts/tasks/exportDeployments";
import verifyContracts from "./scripts/tasks/verifyContracts";
import { BLOCK_NUMBER } from "./constants/constants";
import { TEST_URI } from "./scripts/helpers/getDefaultEthersProvider";

require("dotenv").config();

process.env.TEST_MNEMONIC =
  "test test test test test test test test test test test junk";

// Defaults to CHAINID=1 so things will run with mainnet fork if not specified
const CHAINID = process.env.CHAINID ? Number(process.env.CHAINID) : 137;

export default {
  accounts: {
    mnemonic: process.env.TEST_MNEMONIC,
  },
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        runs: 0,
        enabled: true,
      },
    },
  },
  networks: {
    hardhat: {
      accounts: {
        mnemonic: process.env.POLYGON_MNEMONIC,
      },
      deploy: ["scripts/deploy_polygon"],
      loggingEnabled: true,
      chainId: CHAINID,
      forking: {
        url: TEST_URI[CHAINID],
        blockNumber: BLOCK_NUMBER[CHAINID],
        gasLimit: 8e6,
      },
    },
    polygon: {
      url: process.env.POLYGON_URI,
      chainId: 137,
      deploy: ["scripts/deploy_polygon"],
      loggingEnabled: true,
      gasPrice: 200000000000,
      accounts: process.env.PK.split(",")
    },
    polygon_test: {
      url: process.env.POLYGON_URI,
      chainId: 137,
      deploy: ["scripts/deploy_polygon"],
      loggingEnabled: true,
      accounts: {
        mnemonic: process.env.POLYGON_MNEMONIC,
      }
    },  
    mainnet: {
      url: process.env.TEST_URI,
      chainId: CHAINID,
      accounts: {
        mnemonic: process.env.MAINNET_MNEMONIC,
      },
    },
    kovan: {
      url: process.env.KOVAN_URI,
      chainId: 42,
      accounts: {
        mnemonic: process.env.KOVAN_MNEMONIC,
      },
    },
    avax: {
      url: process.env.AVAX_URI,
      chainId: 43114,
      accounts: {
        mnemonic: process.env.AVAX_MNEMONIC,
      },
    },
    fuji: {
      url: process.env.FUJI_URI,
      chainId: 43113,
      accounts: {
        mnemonic: process.env.FUJI_MNEMONIC,
      },
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
      137: "0x84a9Ea1F5F2F4D0685147B1cD1374f470FcB76dB",
      1: "0x422f7Bb366608723c8fe61Ac6D923023dCCBC3d7",
      42: "0x422f7Bb366608723c8fe61Ac6D923023dCCBC3d7",
      43114: "0x422f7Bb366608723c8fe61Ac6D923023dCCBC3d7",
      43113: "0x004FCF8052D3c7eCb7558ac0068882425a055528",
      1313161554: "0x46B4E6143Fb6ded2e5FBd87887Ef4f50f716dcA0",
      1313161555: "0x46B4E6143Fb6ded2e5FBd87887Ef4f50f716dcA0",
    },
    owner: {
      default: 0,
      137: "0x84a9Ea1F5F2F4D0685147B1cD1374f470FcB76dB",
      1: "0xAb6df2dE75a4f07D95c040DF90c7362bB5edcd90",
      42: "0x92Dd37fbc36cB7260F0d2BD09F9672525a028fB8",
      43114: "0x939cbb6BaBAad2b0533C2CACa8a4aFEc3ae06492",
      43113: "0x004FCF8052D3c7eCb7558ac0068882425a055528",
      1313161554: "0x46B4E6143Fb6ded2e5FBd87887Ef4f50f716dcA0",
      1313161555: "0x46B4E6143Fb6ded2e5FBd87887Ef4f50f716dcA0",
    },
    keeper: {
      default: 0,
      137: "0x84a9Ea1F5F2F4D0685147B1cD1374f470FcB76dB",
      1: "0xAb6df2dE75a4f07D95c040DF90c7362bB5edcd90",
      42: "0x422f7Bb366608723c8fe61Ac6D923023dCCBC3d7",
      43114: "0x422f7Bb366608723c8fe61Ac6D923023dCCBC3d7",
      43113: "0x004FCF8052D3c7eCb7558ac0068882425a055528",
      1313161554: "0xA4290C9EAe274c7A8FbC57A1E68AdC3E95E7C67e",
      1313161555: "0xA4290C9EAe274c7A8FbC57A1E68AdC3E95E7C67e",
    },
    admin: {
      default: 0,
      137: "0x56187FeB620A29E02043F3d9E3dC389d94c3FEA8",
      1: "0x88A9142fa18678003342a8Fd706Bd301E0FecEfd",
      42: "0x422f7Bb366608723c8fe61Ac6D923023dCCBC3d7",
      43114: "0x31351f2BD9e94813BCf0cA04B5E6e2b7ceAFC7c6",
      43113: "0x004FCF8052D3c7eCb7558ac0068882425a055528",
      1313161554: "0x46B4E6143Fb6ded2e5FBd87887Ef4f50f716dcA0",
      1313161555: "0x46B4E6143Fb6ded2e5FBd87887Ef4f50f716dcA0",
    },
    feeRecipient: {
      default: 0,
      137: "0x56187FeB620A29E02043F3d9E3dC389d94c3FEA8",
      1: "0xDAEada3d210D2f45874724BeEa03C7d4BBD41674", // Ribbon DAO
      42: "0x92Dd37fbc36cB7260F0d2BD09F9672525a028fB8",
      43114: "0x939cbb6BaBAad2b0533C2CACa8a4aFEc3ae06492",
      43113: "0x004FCF8052D3c7eCb7558ac0068882425a055528",
      1313161554: "0x46B4E6143Fb6ded2e5FBd87887Ef4f50f716dcA0",
      1313161555: "0x46B4E6143Fb6ded2e5FBd87887Ef4f50f716dcA0",
    },
  },
  mocha: {
    timeout: 500000,
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  gasReporter: {
    enabled: true,
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
  },
};

task("export-deployments", "Exports deployments into JSON", exportDeployments);
task("verify-contracts", "Verify solidity source", verifyContracts);
