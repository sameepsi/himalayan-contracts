import { BigNumber, ethers } from "ethers";
const { parseUnits } = ethers.utils;
import axios from "axios";

require("dotenv").config();

const API_URL = `https://api.etherscan.io/api?module=gastracker&action=gasoracle&apikey=${process.env.ETHERSCAN_API_KEY}`;

async function getGasPrice(isFast = true) {
  const response = await axios.get(API_URL);
  if (response.data.status !== "1") {
    throw new Error("Etherscan error");
  }

  const price = isFast
    ? BigNumber.from(response.data.result.FastGasPrice.toString())
    : BigNumber.from(response.data.result.ProposeGasPrice.toString());

  return price.mul(BigNumber.from("10").pow(BigNumber.from("9")));
}

export async function gas(network: string) {
  if (network === "mainnet") {
    return await getGasPrice();
  }
  return parseUnits("20", "gwei");
}
