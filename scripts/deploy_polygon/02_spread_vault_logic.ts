import { run } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import {
  WETH_ADDRESS,
  USDC_ADDRESS,
  OTOKEN_FACTORY,
  GAMMA_CONTROLLER,
  MARGIN_POOL,
  GNOSIS_EASY_AUCTION,
} from "../../constants/constants";

const main = async ({
  network,
  deployments,
  getNamedAccounts,
}: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  console.log(`01 - Deploying Spread Vault logic on ${network.name}`);

  const chainId = network.config.chainId;

  const lifecycle = await deploy("VaultLifecycleSpread", {
    contract: "VaultLifecycleSpread",
    from: deployer,
  });
  console.log(`VaultLifecycleSpread @ ${lifecycle.address}`);

  const spreadTokenLogic = await deployments.get("SpreadTokenLogic");
  const vault = await deploy("SpreadVaultLogic", {
    contract: "SpreadVault",
    from: deployer,
    args: [
      WETH_ADDRESS[chainId],
      USDC_ADDRESS[chainId],
      OTOKEN_FACTORY[chainId],
      GAMMA_CONTROLLER[chainId],
      MARGIN_POOL[chainId],
      GNOSIS_EASY_AUCTION[chainId],
      spreadTokenLogic.address,
    ],
    libraries: {
      VaultLifecycleSpread: lifecycle.address,
    },
  });
  console.log(`SpreadVaultLogic @ ${vault.address}`);

  try {
    if (vault.newlyDeployed) {
      await run("verify:verify", {
        address: vault.address,
        constructorArguments: [
          WETH_ADDRESS[chainId],
          USDC_ADDRESS[chainId],
          OTOKEN_FACTORY[chainId],
          GAMMA_CONTROLLER[chainId],
          MARGIN_POOL[chainId],
          GNOSIS_EASY_AUCTION[chainId],
          spreadTokenLogic.address,
        ],
      });
      await run("verify:verify", {
        address: lifecycle.address,
        constructorArguments: [],
      });
      
      
    }
  } catch (error) {
    console.log(error);
  }
};
main.tags = ["SpreadVaultLogic"];

export default main;
