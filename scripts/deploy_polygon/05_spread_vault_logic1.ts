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
  console.log(`05 - Deploying Spread Vault logic1 on ${network.name}`);

  const chainId = network.config.chainId;
  const lifecycle = await deployments.get("VaultLifecycleSpread");
  const spreadTokenLogic = await deployments.get("SpreadTokenLogic");
  const allowList = await deployments.get("AllowList");
  const optionsExpiryDuration = 1; // 0 for weekly

  try {
    const vault = await deploy("SpreadVaultLogic1", {
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
        optionsExpiryDuration,
        allowList.address
      ],
      libraries: {
        VaultLifecycleSpread: lifecycle.address,
      },
    });
    console.log(`SpreadVaultLogic1 @ ${vault.address}`);

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
          optionsExpiryDuration,
          allowList.address
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
main.tags = ["SpreadVaultLogic1"];

export default main;
