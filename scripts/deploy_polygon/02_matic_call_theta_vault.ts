import { run } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import {
  CHAINID,
  WETH_ADDRESS,
  USDC_PRICE_ORACLE,
  ETH_PRICE_ORACLE,
  OptionsPremiumPricerInStables_BYTECODE,
} from "../../constants/constants";

import ManualVolOracle_ABI from "../../constants/abis/ManualVolOracle.json";
import OptionsPremiumPricerInStables_ABI from "../../constants/abis/OptionsPremiumPricerInStables.json";
import {
  AUCTION_DURATION,
  STRIKE_STEP,
  MANAGEMENT_FEE,
  PERFORMANCE_FEE,
  PREMIUM_DISCOUNT,
  STRIKE_DELTA,
} from "../utils/constants";
import { getDeltaStep } from "../../test/helpers/utils";

const TOKEN_NAME = {
  [CHAINID.POLYGON_MAINNET]: "Ribbon MATIC Theta Vault",
  [CHAINID.ETH_MAINNET]: "Ribbon ETH Theta Vault",
  [CHAINID.ETH_KOVAN]: "Ribbon ETH Theta Vault",
  [CHAINID.AVAX_MAINNET]: "Ribbon AVAX Theta Vault",
  [CHAINID.AVAX_FUJI]: "Ribbon AVAX Theta Vault"
};

const TOKEN_SYMBOL = {
  [CHAINID.POLYGON_MAINNET]: "rMATIC-THETA",
  [CHAINID.ETH_MAINNET]: "rETH-THETA",
  [CHAINID.ETH_KOVAN]: "rETH-THETA",
  [CHAINID.AVAX_MAINNET]: "rAVAX-THETA",
  [CHAINID.AVAX_FUJI]: "rAVAX-THETA"
};

const STRIKE_STEPS = {
  [CHAINID.POLYGON_MAINNET]: STRIKE_STEP.MATIC,
  [CHAINID.ETH_MAINNET]: STRIKE_STEP.ETH,
  [CHAINID.ETH_KOVAN]: STRIKE_STEP.ETH,
  [CHAINID.AVAX_MAINNET]: STRIKE_STEP.AVAX,
  [CHAINID.AVAX_FUJI]: STRIKE_STEP.AVAX,
};

const main = async ({
  network,
  deployments,
  ethers,
  getNamedAccounts,
}: HardhatRuntimeEnvironment) => {
  const { BigNumber } = ethers;
  const { parseEther } = ethers.utils;
  const { deploy } = deployments;
  const { deployer, owner, keeper, admin, feeRecipient } =
    await getNamedAccounts();
  console.log(`02 - Deploying MATIC Call Theta Vault on ${network.name}`);

  const chainId = network.config.chainId;

  const manualVolOracle = await deployments.get("ManualVolOracle");
  const underlyingOracle = ETH_PRICE_ORACLE[chainId];
  const stablesOracle = USDC_PRICE_ORACLE[chainId];

  const manualVolOracleContract = await ethers.getContractAt(ManualVolOracle_ABI, manualVolOracle.address);
  const optionId = await manualVolOracleContract.getOptionId(
    getDeltaStep("MATIC"),
    WETH_ADDRESS[chainId],
    WETH_ADDRESS[chainId],
    false
  );
  
  const pricer = await deploy("OptionsPremiumPricerMatic", {
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

  console.log(`RibbonThetaVaultMATICCall pricer @ ${pricer.address}`);

  // Can't verify pricer because it's compiled with 0.7.3

  const strikeSelection = await deploy("StrikeSelectionMATIC", {
    contract: "DeltaStrikeSelection",
    from: deployer,
    args: [pricer.address, STRIKE_DELTA, STRIKE_STEPS[chainId]],
  });

  console.log(
    `RibbonThetaVaultMATICCall strikeSelection @ ${strikeSelection.address}`
  );

  try {
    await run("verify:verify", {
      address: strikeSelection.address,
      constructorArguments: [
        pricer.address,
        STRIKE_DELTA,
        STRIKE_STEPS[chainId]
      ],
    });
  } catch (error) {
    console.log(error);
  }

  const logicDeployment = await deployments.get("RibbonThetaVaultLogic");
  const RibbonThetaVault = await ethers.getContractFactory("RibbonThetaVault");

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
      _isUsdcAuction: false,
      _swapPath: 0x0,
    },
    {
      isPut: false,
      decimals: 18,
      asset: WETH_ADDRESS[chainId],
      underlying: WETH_ADDRESS[chainId],
      minimumSupply: BigNumber.from(10).pow(10),
      cap: parseEther("1000"),
    },
  ];

  const initData = RibbonThetaVault.interface.encodeFunctionData(
    "initialize",
    initArgs
  );

  const proxy = await deploy("RibbonThetaVaultMATICCall", {
    contract: "AdminUpgradeabilityProxy",
    from: deployer,
    args: [logicDeployment.address, admin, initData],
  });

  console.log(`RibbonThetaVaultMATICCall Proxy @ ${proxy.address}`);

  try {
    await run("verify:verify", {
      address: proxy.address,
      constructorArguments: [logicDeployment.address, admin, initData],
    });
  } catch (error) {
    console.log(error);
  }
};
main.tags = ["RibbonThetaVaultMATICCall"];
main.dependencies = ["ManualVolOracle", "RibbonThetaVaultLogic"];

export default main;
