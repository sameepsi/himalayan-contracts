import { HardhatRuntimeEnvironment } from "hardhat/types";


const main = async ({
  network,
  deployments,
  getNamedAccounts,
}: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  console.log("00 - Deploying ManualVolOracle on", network.name);

  const { deployer, keeper } = await getNamedAccounts();

  const oracle = await deploy("ManualVolOracle", {
    from: deployer,
    contract: "ManualVolOracle",
    args: [keeper],
  });

  console.log(`ManualVolOracle @ ${oracle.address}`);

  // Cannot verify because of compiler mismatch.
};
main.tags = ["ManualVolOracle"];

export default main;
