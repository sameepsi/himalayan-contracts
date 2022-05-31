import { ethers } from "ethers";
import { CHAINID } from "../../constants/constants";

require("dotenv").config();

export const TEST_URI = {
  [CHAINID.POLYGON_MAINNET]: process.env.POLYGON_URI,
  [CHAINID.POLYGON_TESTNET]: process.env.MUMBAI_URI,
  [CHAINID.ETH_MAINNET]: process.env.TEST_URI,
  [CHAINID.AVAX_MAINNET]: process.env.AVAX_URI,
  [CHAINID.AVAX_FUJI]: process.env.FUJI_URI,
  [CHAINID.AURORA_MAINNET]: process.env.AURORA_URI,
  [CHAINID.AURORA_TESTNET]: process.env.AURORA_TESTNET_URI,
};

export type Networks = "polygon" | "mumbai";

export const getDefaultProvider = (network: Networks = "polygon") => {
  const url =
    network === "polygon"
      ? process.env.POLYGON_URI
      : process.env.MUMBAI_URI;

  const provider = new ethers.providers.JsonRpcProvider(url);

  return provider;
};

export const getDefaultSigner = (path: string, network: Networks = "polygon") => {
  const mnemonic =
    network === "polygon"
      ? process.env.POLYGON_MNEMONIC
      : process.env.MUMBAI_MNEMONIC;

  if (!mnemonic) {
    throw new Error("No mnemonic set");
  }
  const signer = ethers.Wallet.fromMnemonic(mnemonic, path);
  return signer;
};
