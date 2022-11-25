import { run } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import {
  ETHER_ADDRESS,
  WETH_PRICE_ORACLE,
  USDC_PRICE_ORACLE,
  WETH_USDC_POOL,
  OptionsPremiumPricerInStables_BYTECODE,
  CHAINID,
} from "../../constants/constants";
import OptionsPremiumPricerInStables_ABI from "../../constants/abis/OptionsPremiumPricerInStables.json";
import ManualVolOracle_ABI from "../../constants/abis/ManualVolOracle.json";
import {
  AUCTION_DURATION,
  MANAGEMENT_FEE,
  PERFORMANCE_FEE,
  PREMIUM_DISCOUNT,
  STRIKE_DELTA,
  STRIKE_STEP,
} from "../utils/constants";
import { getDeltaStep } from "../../test/helpers/utils";
import { parseEther } from "ethers/lib/utils";

const main = async ({
  network,
  deployments,
  ethers,
  getNamedAccounts,
}: HardhatRuntimeEnvironment) => {
  const chainId = network.config.chainId;

  if (chainId !== CHAINID.POLYGON_MAINNET) {
    console.log(
      `06 - Skipping deployment AAVE Call Theta Vault on ${network.name}`
    );
    return;
  }
  const { BigNumber } = ethers;
  const { parseUnits } = ethers.utils;
  const { deploy } = deployments;
  const { deployer, owner, keeper, admin, feeRecipient } =
    await getNamedAccounts();
  console.log(`03 - Deploying ETH Call 30 Theta Vault on ${network.name}`);

  const manualVolOracle = await deployments.get("ManualVolOracle");
  const underlyingOracle = WETH_PRICE_ORACLE[chainId];
  const stablesOracle = USDC_PRICE_ORACLE[chainId];

  const manualVolOracleContract = await ethers.getContractAt(ManualVolOracle_ABI, manualVolOracle.address);
  const optionId = await manualVolOracleContract.getOptionId(
    "30",
    ETHER_ADDRESS[chainId],
    ETHER_ADDRESS[chainId],
    false
  );
  
  const pricer = await deploy("OptionsPremiumPricerETH30", {
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

  console.log(`RibbonThetaVaultETHCall 30% pricer @ ${pricer.address}`);

  // Can't verify pricer because it's compiled with 0.7.3

  const strikeSelection = await deploy("StrikeSelectionETH30", {
    contract: "ManualStrikeSelection",
    from: deployer,
    args: [],
  });


  console.log(
    `RibbonThetaVaultETHCall 30% strikeSelection @ ${strikeSelection.address}`
  );

  try {
    await run("verify:verify", {
      address: strikeSelection.address,
      constructorArguments: [],
    });
  } catch (error) {
    console.log(error);
  }

  const logicDeployment = await deployments.get("RibbonThetaVaultLogic");
  const lifecycle = await deployments.get("VaultLifecycle");

  const RibbonThetaVault = await ethers.getContractFactory("RibbonThetaVault", {
    libraries: {
      VaultLifecycle: lifecycle.address,
    },
  });

  const initArgs = [
    {
      _owner: owner,
      _keeper: keeper,
      _feeRecipient: feeRecipient,
      _managementFee: MANAGEMENT_FEE,
      _performanceFee: PERFORMANCE_FEE,
      _tokenName: "Himalayan ETH Vault 30",
      _tokenSymbol: "rETH30",
      _optionsPremiumPricer: pricer.address,
      _strikeSelection: strikeSelection.address,
      _premiumDiscount: PREMIUM_DISCOUNT,
      _auctionDuration: AUCTION_DURATION,
      _isUsdcAuction: false,
      _swapPath: 0x0,
    },
    {
      isPut: false,
      decimals: 8,
      asset: ETHER_ADDRESS[chainId],
      underlying: ETHER_ADDRESS[chainId],
      minimumSupply: BigNumber.from(10).pow(3),
      cap: parseEther("125"),
    },
  ];
  const initData = RibbonThetaVault.interface.encodeFunctionData(
    "initialize",
    initArgs
  );

  const proxy = await deploy("RibbonThetaVaultETHCall30", {
    contract: "AdminUpgradeabilityProxy",
    from: deployer,
    args: [logicDeployment.address, admin, initData],
  });

  console.log(`RibbonThetaVaultETHCall 30% @ ${proxy.address}`);

  try {
    await run("verify:verify", {
      address: proxy.address,
      constructorArguments: [logicDeployment.address, admin, initData],
    });
  } catch (error) {
    console.log(error);
  }
};
main.tags = ["RibbonThetaVaultETHCall30"];
main.dependencies = ["ManualVolOracle", "RibbonThetaVaultLogic"];

export default main;
