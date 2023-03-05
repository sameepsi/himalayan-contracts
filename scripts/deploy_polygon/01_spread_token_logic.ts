import hre, { run } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { GAMMA_CONTROLLER } from "../../constants/constants";

const main = async ({
  network,
  deployments,
  getNamedAccounts,
}: HardhatRuntimeEnvironment) => {

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  console.log(`01 - Deploying SpreadToken logic on ${network.name}`);
  const chainId = network.config.chainId;

  const spreadTokenLogic = await deploy("SpreadTokenLogic", {
    contract: "SpreadToken",
    from: deployer,
    args: [GAMMA_CONTROLLER[chainId]],
  });
  console.log(`SpreadTokenLogic @ ${spreadTokenLogic.address}`);

  if (spreadTokenLogic.newlyDeployed) {
    try {
      await run("verify:verify", {
        address: spreadTokenLogic.address,
        constructorArguments: [GAMMA_CONTROLLER[chainId]],
      });
    } catch (error) {
      console.log(error);
    }
  }

};
main.tags = ["SpreadTokenLogic"];

export default main;
