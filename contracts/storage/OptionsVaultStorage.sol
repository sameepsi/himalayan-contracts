// SPDX-License-Identifier: MIT
pragma solidity >=0.7.2;

import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Vault} from "../libraries/Vault.sol";
import {StrikeOverride} from "../libraries/StrikeOverride.sol";

abstract contract OptionsVaultStorageV1 is
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    ERC20Upgradeable
{
    // Mapping to store the scheduled withdrawals (address => withdrawAmount)
    mapping(address => uint256) public scheduledWithdrawals;

    /// @notice Stores the user's pending deposit for the round
    mapping(address => Vault.DepositReceipt) public depositReceipts;

    /// @notice On every round's close, the pricePerShare value of an rTHETA token is stored
    /// This is used to determine the number of shares to be returned
    /// to a user with their DepositReceipt.depositAmount
    mapping(uint16 => uint256) public roundPricePerShare;

    /// @notice Stores pending user withdrawals
    mapping(address => Vault.Withdrawal) public withdrawals;

    Vault.VaultParams public vaultParams;

    Vault.VaultState public vaultState;

    Vault.OptionState public optionState;

    address public feeRecipient;

    uint256 public performanceFee;

    uint256 public managementFee;
}

abstract contract OptionsThetaVaultStorageV1 {
    // Logic contract used to price options
    address optionsPremiumPricer;
    // Logic contract used to select strike prices
    address strikeSelection;
    // Premium discount on options we are selling (thousandths place: 000 - 999)
    uint32 premiumDiscount;
    // Current oToken premium
    uint104 currentOtokenPremium;
    // Last round id at which the strike was manually overridden
    uint16 lastStrikeOverride;
    // Price last overridden strike set to
    uint128 overriddenStrikePrice;
    // Auction id of current option
    uint256 optionAuctionID;
}

abstract contract OptionsDeltaVaultStorageV1 {
    // Ribbon counterparty theta vault
    address counterpartyThetaVault;
    // % of funds to be used for weekly option purchase
    uint256 optionAllocationPct;
}

// We are following Compound's method of upgrading new contract implementations
// When we need to add new storage variables, we create a new version of OptionsVaultStorage
// e.g. OptionsVaultStorageV<versionNumber>, so finally it would look like
// contract OptionsVaultStorage is OptionsVaultStorageV1, OptionsVaultStorageV2
abstract contract OptionsVaultStorage is OptionsVaultStorageV1 {

}

abstract contract OptionsThetaVaultStorage is OptionsThetaVaultStorageV1 {}

abstract contract OptionsDeltaVaultStorage is OptionsDeltaVaultStorageV1 {}
