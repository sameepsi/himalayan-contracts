import { run } from "hardhat";
import {
  CHAINID,
  WETH_ADDRESS,
  USDC_PRICE_ORACLE,
  ETH_PRICE_ORACLE,
  OptionsPremiumPricerInStables_BYTECODE,
} from "../../constants/constants";

import {
  AUCTION_DURATION,
  MANAGEMENT_FEE,
  PERFORMANCE_FEE,
  PREMIUM_DISCOUNT,
} from "../utils/constants";
import OptionsPremiumPricerInStables_ABI from "../../constants/abis/OptionsPremiumPricerInStables.json";
import ManualVolOracle_ABI from "../../constants/abis/ManualVolOracle.json";

const TOKEN_NAME = {
  [CHAINID.POLYGON_MAINNET]: "Himalayan MATIC Call Spread Vault",
  [CHAINID.ETH_MAINNET]: "Himalayan ETH Theta Vault",
  [CHAINID.ETH_KOVAN]: "Himalayan ETH Theta Vault",
  [CHAINID.AVAX_MAINNET]: "Himalayan AVAX Theta Vault",
  [CHAINID.AVAX_FUJI]: "Himalayan AVAX Theta Vault"
};

const TOKEN_SYMBOL = {
  [CHAINID.POLYGON_MAINNET]: "hMATIC-CS",
  [CHAINID.ETH_MAINNET]: "rETH-THETA",
  [CHAINID.ETH_KOVAN]: "rETH-THETA",
  [CHAINID.AVAX_MAINNET]: "rAVAX-THETA",
  [CHAINID.AVAX_FUJI]: "rAVAX-THETA"
};

const main = async ({
  network,
  deployments,
  ethers,
  getNamedAccounts,
}) => {
  const { BigNumber } = ethers;
  const { parseEther } = ethers.utils;
  const { deploy } = deployments;
  const { deployer, owner, keeper, admin, feeRecipient } = await getNamedAccounts();
  console.log(`06 - Deploying MATIC Call SPREAD Vault1 on ${network.name}`);

  const chainId = network.config.chainId;

  // Can't verify pricer because it's compiled with 0.7.3
  const manualVolOracle = await deployments.get("ManualVolOracle");
  const manualVolOracleContract = await ethers.getContractAt(ManualVolOracle_ABI, manualVolOracle.address);
  const optionId = await manualVolOracleContract.getOptionId(
    "10", // dynamic delta required
    WETH_ADDRESS[chainId], // underlying
    WETH_ADDRESS[chainId], // collateralAsset
    false // isPut
  );

  const underlyingOracle = ETH_PRICE_ORACLE[chainId];
  const stablesOracle = USDC_PRICE_ORACLE[chainId];

  const pricer = await deploy("OptionsPremiumPricerMaticCallSpread1", {
    from: deployer,
    contract: {
      abi: OptionsPremiumPricerInStables_ABI,
      bytecode: OptionsPremiumPricerInStables_BYTECODE,
    },
    args: [
      optionId,
      manualVolOracle.address,
      underlyingOracle,
      stablesOracle,
    ],
  });

  console.log(`OptionsPremiumPricerMaticCallSpread1 pricer @ ${pricer.address}`);

  const strikeSelection = await deploy("StrikeSelectionMATICCallSpread1", {
    contract: "ManualStrikeSelectionCallSpread",
    from: deployer,
    args: [],
  });
  console.log(`StrikeSelectionMATICCallSpread1 strikeSelection @ ${strikeSelection.address}`);

  try {
    if (strikeSelection.newlyDeployed) {
      await run("verify:verify", {
        address: strikeSelection.address,
        constructorArguments: [],
      });
    }
  } catch (error) {
    console.log(error);
  }

  const logicDeployment = await deployments.get("SpreadVaultLogic1");
  const lifecycle = await deployments.get("VaultLifecycleSpread");

  const HimalayanSpreadVault = await ethers.getContractFactory("SpreadVault", {
    libraries: {
      VaultLifecycleSpread: lifecycle.address,
    },
  });

  const initArgs = [
    {
      _owner: owner,
      _keeper: keeper,
      _feeRecipient: feeRecipient,
      _managementFee: MANAGEMENT_FEE,
      _performanceFee: PERFORMANCE_FEE,
      _tokenName: TOKEN_NAME[chainId],
      _tokenSymbol: TOKEN_SYMBOL[chainId],
      _optionsPremiumPricer: pricer.address,
      _strikeSelection: strikeSelection.address,
      _premiumDiscount: PREMIUM_DISCOUNT,
      _auctionDuration: AUCTION_DURATION,
    },
    {
      isPut: false,
      isSpread: true,
      decimals: 18,
      asset: WETH_ADDRESS[chainId],
      underlying: WETH_ADDRESS[chainId],
      minimumSupply: BigNumber.from(10).pow(10),
      cap: parseEther("250000"),
    },
  ];

  const initData = HimalayanSpreadVault.interface.encodeFunctionData(
    "initialize",
    initArgs
  );

  const proxy = await deploy("HimalayanCallSpreadMatic1", {
    contract: "AdminUpgradeabilityProxy",
    from: deployer,
    args: [logicDeployment.address, admin, initData],
  });
  console.log(`HimalayanCallSpreadMatic1 %Proxy @ ${proxy.address}`);

  try {
    if (proxy.newlyDeployed) {
      await run("verify:verify", {
        address: proxy.address,
        constructorArguments: [logicDeployment.address, admin, initData],
      });
    }
  } catch (error) {
    console.log(error);
  }
};
main.tags = ["HimalayanCallSpreadMatic1"];
main.dependencies = ["CallSpreadLogic1"];

export default main;
