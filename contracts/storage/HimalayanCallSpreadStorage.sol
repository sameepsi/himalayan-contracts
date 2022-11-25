// SPDX-License-Identifier: MIT
pragma solidity =0.8.12;

abstract contract HimalayanCallSpreadStorage {
    // Logic contract used to price options
    address public optionsPremiumPricer;
    // Logic contract used to select strike prices
    address public strikeSelection;
    // Premium discount on options we are selling (thousandths place: 000 - 999)
    uint256 public premiumDiscount;
    // Current oToken premium
    uint256 public currentOtokenPremium;
    // Auction duration
    uint256 public auctionDuration;
    // Auction id of current option
    uint256 public optionAuctionID;
     // Amount locked for scheduled withdrawals last week;
    uint256 public lastQueuedWithdrawAmount;
    // OptionsPurchaseQueue contract for selling options
    address public optionsPurchaseQueue;
    // Queued withdraw shares for the current round
    uint256 public currentQueuedWithdrawShares;
    // Vault Pauser Contract for the vault
    address public vaultPauser;

}
