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

const TOKEN_NAME = {
  [CHAINID.POLYGON_MAINNET]: "Himalayan MATIC Spread Vault",
  [CHAINID.ETH_MAINNET]: "Himalayan ETH Theta Vault",
  [CHAINID.ETH_KOVAN]: "Himalayan ETH Theta Vault",
  [CHAINID.AVAX_MAINNET]: "Himalayan AVAX Theta Vault",
  [CHAINID.AVAX_FUJI]: "Himalayan AVAX Theta Vault"
};

const TOKEN_SYMBOL = {
  [CHAINID.POLYGON_MAINNET]: "hSMATIC10",
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
}: HardhatRuntimeEnvironment) => {
  const { BigNumber } = ethers;
  const { parseEther } = ethers.utils;
  const { deploy } = deployments;
  const { deployer, owner, keeper, admin, feeRecipient } =
    await getNamedAccounts();
  console.log(`02 - Deploying MATIC Call Theta Vault 10% on ${network.name}`);

  const chainId = network.config.chainId;


  // Can't verify pricer because it's compiled with 0.7.3

  const strikeSelection = await deploy("StrikeSelectionMATICSpread", {
    contract: "ManualStrikeSelectionCallSpread",
    from: deployer,
    args: [],
  });

  const StrikeSelection = await ethers.getContractFactory('ManualStrikeSelectionCallSpread');
  const strikeSelectionInstance = await StrikeSelection.attach(strikeSelection.address);

  console.log(
    `HimalayanCallSpreadMatic strikeSelection @ ${strikeSelection.address}`
  );

  try {

    if(strikeSelection.newlyDeployed) {
      await run("verify:verify", {
        address: strikeSelection.address,
        constructorArguments: [],
      });
    }
  } catch (error) {
    console.log(error);
  }

  const logicDeployment = await deployments.get("CallSpreadLogic");
  const lifecycle = await deployments.get("VaultLifecycleSpread");

  const HimalayanSpreadVault = await ethers.getContractFactory("CallSpread", {
    libraries: {
      VaultLifecycleSpread: lifecycle.address,
    },
  });;

  const initArgs = [
    {
      _owner: owner,
      _keeper: keeper,
      _feeRecipient: feeRecipient,
      _managementFee: MANAGEMENT_FEE,
      _performanceFee: PERFORMANCE_FEE,
      _tokenName: TOKEN_NAME[chainId],
      _tokenSymbol: TOKEN_SYMBOL[chainId],
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

  const proxy = await deploy("HimalayanCallSpreadMatic", {
    contract: "AdminUpgradeabilityProxy",
    from: deployer,
    args: [logicDeployment.address, admin, initData],
  });

  console.log(`HimalayanCallSpreadMatic 10 %Proxy @ ${proxy.address}`);

  const himalayanSpreadVault = HimalayanSpreadVault.attach(proxy.address);
  
  try {
    if(!proxy.newlyDeployed) {
      await strikeSelectionInstance.setStrikePrice([78000000,95000000]);
      await himalayanSpreadVault.setMinPrice(5000000000000000)
      await run("verify:verify", {
        address: proxy.address,
        constructorArguments: [logicDeployment.address, admin, initData],
      });
    }
  } catch (error) {
    console.log(error);
  }
};
main.tags = ["HimalayanCallSpreadMatic"];
main.dependencies = ["CallSpreadLogic"];

export default main;
