// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {GnosisAuction} from "../../libraries/GnosisAuction.sol";
import {
    HimalayanCallSpreadStorage
} from "../../storage/HimalayanCallSpreadStorage.sol";
import {Vault} from "../../libraries/Vault.sol";
import {VaultLifecycleSpread} from "../../libraries/VaultLifecycleSpread.sol";
import {ShareMath} from "../../libraries/ShareMath.sol";
import {HimalayanVault} from "./base/HimalayanVault.sol";
import {IOtoken} from "../../interfaces/GammaInterface.sol";
import {ISpreadToken} from "../../interfaces/IHimalayan.sol";

/**
 * UPGRADEABILITY: Since we use the upgradeable proxy pattern, we must observe
 * the inheritance chain closely.
 * Any changes/appends in storage variable needs to happen in HimalayanCallSpreadStorage.
 * CallSpread should not inherit from any other contract aside from HimalayanVault, HimalayanCallSpreadStorage
 */
contract SpreadVault is HimalayanVault, HimalayanCallSpreadStorage {
    using SafeERC20 for IERC20;
    using ShareMath for Vault.DepositReceipt;

    /************************************************
     *  IMMUTABLES & CONSTANTS
     ***********************************************/

    /// @notice oTokenFactory is the factory contract used to spawn otokens. Used to lookup otokens.
    address public immutable OTOKEN_FACTORY;

    // The minimum duration for an option auction.
    uint256 private constant MIN_AUCTION_DURATION = 5 minutes;

    /************************************************
     *  EVENTS
     ***********************************************/

    event OpenSpread(
        address[] spread,
        uint256 depositAmount,
        address indexed manager,
        address indexed spreadToken
    );

    event CloseSpread(
        address[] spread,
        uint256 withdrawAmount,
        address indexed manager,
        address indexed spreadToken
    );

    event NewSpreadStrikesSelected(
        uint256[] strikePrices,
        uint256[] deltas,
        address spreadToken
    );

    event PremiumDiscountSet(
        uint256 premiumDiscount,
        uint256 newPremiumDiscount
    );

    event AuctionDurationSet(
        uint256 auctionDuration,
        uint256 newAuctionDuration
    );

    event InstantWithdraw(
        address indexed account,
        uint256 amount,
        uint256 round
    );

    /************************************************
     *  STRUCTS
     ***********************************************/

    /**
     * @notice Initialization parameters for the vault.
     * @param _owner is the owner of the vault with critical permissions
     * @param _feeRecipient is the address to recieve vault performance and management fees
     * @param _managementFee is the management fee pct.
     * @param _performanceFee is the perfomance fee pct.
     * @param _tokenName is the name of the token
     * @param _tokenSymbol is the symbol of the token
     * @param _optionsPremiumPricer is the address of the contract with the
       black-scholes premium calculation logic
     * @param _strikeSelection is the address of the contract with strike selection logic
     * @param _premiumDiscount is the vault's discount applied to the premium
     * @param _auctionDuration is the duration of the gnosis auction
     */
    struct InitParams {
        address _owner;
        address _keeper;
        address _feeRecipient;
        uint256 _managementFee;
        uint256 _performanceFee;
        string _tokenName;
        string _tokenSymbol;
        address _optionsPremiumPricer;
        address _strikeSelection;
        uint32 _premiumDiscount;
        uint256 _auctionDuration;
    }

    /************************************************
     *  CONSTRUCTOR & INITIALIZATION
     ***********************************************/

    /**
     * @notice Initializes the contract with immutable variables
     * @param _wnative is the Wrapped Native contract
     * @param _usdc is the USDC contract
     * @param _oTokenFactory is the contract address for minting new opyn option types (strikes, asset, expiry)
     * @param _gammaController is the contract address for opyn actions
     * @param _marginPool is the contract address for providing collateral to opyn
     * @param _gnosisEasyAuction is the contract address that facilitates gnosis auctions
     * @param _spreadTokenLogic Spread token logic contract
     * @param _optionsExpiryInDays is duration for options expiry in days.
     */
    constructor(
        address _wnative,
        address _usdc,
        address _oTokenFactory,
        address _gammaController,
        address _marginPool,
        address _gnosisEasyAuction,
        address _spreadTokenLogic,
        uint256 _optionsExpiryInDays,
        address _allowList
    )
        HimalayanVault(
            _wnative,
            _usdc,
            _gammaController,
            _marginPool,
            _gnosisEasyAuction,
            _spreadTokenLogic,
            _optionsExpiryInDays,
            _allowList
        )
    {
        require(_oTokenFactory != address(0), "!_oTokenFactory");
        OTOKEN_FACTORY = _oTokenFactory;
    }

    /**
     * @notice Initializes the OptionVault contract with storage variables.
     * @param _initParams is the struct with vault initialization parameters
     * @param _vaultParams is the struct with vault general data
     */
    function initialize(
        InitParams calldata _initParams,
        Vault.VaultParams calldata _vaultParams
    ) external initializer {
        baseInitialize(
            _initParams._owner,
            _initParams._keeper,
            _initParams._feeRecipient,
            _initParams._managementFee,
            _initParams._performanceFee,
            _initParams._tokenName,
            _initParams._tokenSymbol,
            _vaultParams
        );
        require(
            _initParams._optionsPremiumPricer != address(0),
            "!_optionsPremiumPricer"
        );
        require(
            _initParams._strikeSelection != address(0),
            "!_strikeSelection"
        );
        require(
            _initParams._premiumDiscount > 0 &&
                _initParams._premiumDiscount <
                100 * Vault.PREMIUM_DISCOUNT_MULTIPLIER,
            "!_premiumDiscount"
        );
        require(
            _initParams._auctionDuration >= MIN_AUCTION_DURATION,
            "!_auctionDuration"
        );
        optionsPremiumPricer = _initParams._optionsPremiumPricer;
        strikeSelection = _initParams._strikeSelection;
        premiumDiscount = _initParams._premiumDiscount;
        auctionDuration = _initParams._auctionDuration;
    }

    /************************************************
     *  SETTERS
     ***********************************************/

    /**
     * @notice Sets the new discount on premiums for options we are selling
     * @param newPremiumDiscount is the premium discount
     */
    function setPremiumDiscount(uint256 newPremiumDiscount)
        external
        onlyKeeper
    {
        require(
            newPremiumDiscount > 0 &&
                newPremiumDiscount <= 100 * Vault.PREMIUM_DISCOUNT_MULTIPLIER,
            "Invalid discount"
        );

        emit PremiumDiscountSet(premiumDiscount, newPremiumDiscount);

        premiumDiscount = newPremiumDiscount;
    }

    /**
     * @notice Sets the new options premium pricer contract
     * @param newOptionsPremiumPricer is the address of the new strike selection contract
     */
    function setOptionsPremiumPricer(address newOptionsPremiumPricer)
        external
        onlyOwner
    {
        require(
            newOptionsPremiumPricer != address(0),
            "!newOptionsPremiumPricer"
        );
        optionsPremiumPricer = newOptionsPremiumPricer;
    }

    /**
     * @notice Sets the new auction duration
     * @param newAuctionDuration is the auction duration
     */
    function setAuctionDuration(uint256 newAuctionDuration) external onlyOwner {
        require(
            newAuctionDuration >= MIN_AUCTION_DURATION,
            "Invalid auction duration"
        );

        emit AuctionDurationSet(auctionDuration, newAuctionDuration);

        auctionDuration = newAuctionDuration;
    }

    /**
     * @notice Sets the new strike selection contract
     * @param newStrikeSelection is the address of the new strike selection contract
     */
    function setStrikeSelection(address newStrikeSelection) external onlyOwner {
        require(newStrikeSelection != address(0), "!newStrikeSelection");
        strikeSelection = newStrikeSelection;
    }

    /**
     * @notice Sets oToken Premium
     * @param minPrice is the new oToken Premium in the units of 10**18
     */
    function setMinPrice(uint256 minPrice) external onlyKeeper {
        require(minPrice > 0, "!minPrice");
        currentSpreadPremium = minPrice;
    }

    /************************************************
     *  VAULT OPERATIONS
     ***********************************************/

    /**
     * @notice Withdraws the assets on the vault using the outstanding `DepositReceipt.amount`
     * @param amount is the amount to withdraw
     */
    function withdrawInstantly(uint256 amount) external nonReentrant {
        Vault.DepositReceipt storage depositReceipt =
            depositReceipts[msg.sender];

        uint256 currentRound = vaultState.round;
        require(amount > 0, "!amount");
        require(depositReceipt.round == currentRound, "Invalid round");

        uint256 receiptAmount = depositReceipt.amount;
        require(receiptAmount >= amount, "Exceed amount");

        // Subtraction underflow checks already ensure it is smaller than uint104
        depositReceipt.amount = uint104(receiptAmount - amount);
        vaultState.totalPending = uint128(
            uint256(vaultState.totalPending) - amount
        );

        emit InstantWithdraw(msg.sender, amount, currentRound);

        transferAsset(msg.sender, amount);
    }

    /**
     * @notice Initiates a withdrawal that can be processed once the round completes
     * @param numShares is the number of shares to withdraw
     */
    function initiateWithdraw(uint256 numShares) external nonReentrant {
        _initiateWithdraw(numShares);
        currentQueuedWithdrawShares = currentQueuedWithdrawShares + numShares;
    }

    /**
     * @notice Completes a scheduled withdrawal from a past round. Uses finalized pps for the round
     */
    function completeWithdraw() external nonReentrant {
        uint256 withdrawAmount = _completeWithdraw();
        lastQueuedWithdrawAmount = uint128(
            uint256(lastQueuedWithdrawAmount) - withdrawAmount
        );
    }

    /**
     * @notice Sets the next call spread the vault will be setting up existing the vault.
     *         This allows all the users to withdraw if the next option is malicious.
     */
    function commitAndClose() external nonReentrant {
        address[] memory oldSpread = spreadState.currentSpread;
        address oldSpreadToken = spreadState.currentSpreadToken;

        VaultLifecycleSpread.CloseParams memory closeParams =
            VaultLifecycleSpread.CloseParams({
                OTOKEN_FACTORY: OTOKEN_FACTORY,
                USDC: USDC,
                currentSpread: oldSpread,
                delay: 0,
                strikeSelection: strikeSelection,
                premiumDiscount: premiumDiscount,
                SPREAD_TOKEN_IMPL: SPREAD_TOKEN
            });

        (
            address[] memory spread,
            uint256[]  memory strikePrices,
            uint256[] memory deltas,
            address spreadToken
        ) = VaultLifecycleSpread.commitAndClose(closeParams, vaultParams, vaultState, OPTIONS_EXPIRY_IN_DAYS);

        emit NewSpreadStrikesSelected(strikePrices, deltas, spreadToken);

        bool isPut = vaultParams.isPut;

        if (isPut) {
            require(
                IOtoken(spread[0]).strikePrice() > IOtoken(spread[1]).strikePrice(),
                "Short put otoken must have higher strike price then long put otoken"
            );
        }
        else {
            require(
                IOtoken(spread[0]).strikePrice() < IOtoken(spread[1]).strikePrice(),
                "Short otoken must have less strike price then long token"
            );
        }

        spreadState.nextSpread = spread;
        spreadState.nextSpreadToken = spreadToken;

        uint256 nextOptionReady = block.timestamp;
        require(
            nextOptionReady <= type(uint32).max,
            "Overflow nextOptionReady"
        );
        spreadState.nextOptionReadyAt = uint32(nextOptionReady);

        _closeSpread(oldSpread, oldSpreadToken);
    }

    /**
     * @notice Closes the existing short position for the vault.
     */
    function _closeSpread(address[] memory oldSpread, address oldSpreadToken) private {
        uint256 lockedAmount = vaultState.lockedAmount;
        if (oldSpread.length > 0 && oldSpread[0] != address(0)) {
            vaultState.lastLockedAmount = uint104(lockedAmount);
        }
        vaultState.lockedAmount = 0;
        vaultState.lockedAmountUsed = 0;

        delete spreadState.currentSpread;

        if (oldSpread.length > 0 && oldSpread[0] != address(0)) {
            uint256 withdrawAmount =
                VaultLifecycleSpread.settleSpread(GAMMA_CONTROLLER, oldSpreadToken);
            emit CloseSpread(oldSpread, withdrawAmount, msg.sender, oldSpreadToken);
        }
    }

    /**
     * @notice Rolls the vault's funds into a new short position.
     */
    function rollToNextOption(uint256 index) external onlyKeeper nonReentrant {
        uint256 currQueuedWithdrawShares = currentQueuedWithdrawShares;
        uint104 lockedAmountUsed = vaultState.lockedAmountUsed;
        address[] memory newSpread = spreadState.currentSpread;
        uint256 lockedBalance = vaultState.lockedAmount;
        address spreadToken = spreadState.currentSpreadToken;
        uint256 queuedWithdrawAmount = 0;
        uint256 totalMinted = 0;

        if (lockedAmountUsed == 0) {
            (
                newSpread,
                lockedBalance,
                queuedWithdrawAmount,
                spreadToken
            ) =
                _rollToNextOption(
                    lastQueuedWithdrawAmount,
                    currQueuedWithdrawShares
                );

            lastQueuedWithdrawAmount = queuedWithdrawAmount;

            uint256 newQueuedWithdrawShares =
                uint256(vaultState.queuedWithdrawShares) + currQueuedWithdrawShares;
            ShareMath.assertUint128(newQueuedWithdrawShares);
            vaultState.queuedWithdrawShares = uint128(newQueuedWithdrawShares);

            currentQueuedWithdrawShares = 0;

            ShareMath.assertUint104(lockedBalance);
            vaultState.lockedAmount = uint104(lockedBalance);

            emit OpenSpread(newSpread, lockedBalance, msg.sender, spreadToken);
        }

        lockedBalance = lockedBalance - lockedAmountUsed;

        while (index > 0 && lockedBalance > 0) {
            (uint256 optionsMintAmount, uint256 collateralUsed) =
                VaultLifecycleSpread.createSpread(
                    GAMMA_CONTROLLER,
                    MARGIN_POOL,
                    newSpread,
                    lockedBalance,
                    spreadToken,
                    lockedAmountUsed == 0
                );

            totalMinted = totalMinted + optionsMintAmount;
            index = index - 1;
            lockedAmountUsed = lockedAmountUsed + uint104(collateralUsed);

            lockedBalance = lockedBalance - collateralUsed;
        }
        vaultState.lockedAmountUsed = vaultState.lockedAmountUsed + lockedAmountUsed;
        ISpreadToken(spreadToken).mint(totalMinted);

    }

    /**
     * @notice Initiate the gnosis auction.
     */
    function startAuction() external onlyKeeper nonReentrant {
        GnosisAuction.AuctionDetails memory auctionDetails;

        address currentSellToken = spreadState.currentSpreadToken;

        auctionDetails.tokenAddress = currentSellToken;
        auctionDetails.gnosisEasyAuction = GNOSIS_EASY_AUCTION;
        auctionDetails.asset = vaultParams.asset;
        auctionDetails.assetDecimals = vaultParams.decimals;
        auctionDetails.premium = currentSpreadPremium;
        auctionDetails.duration = auctionDuration;

        optionAuctionID = VaultLifecycleSpread.startAuction(auctionDetails);
    }

    /**
     * @notice Recovery function that returns an ERC20 token to the recipient
     * @param token is the ERC20 token to recover from the vault
     * @param recipient is the recipient of the recovered tokens
     */
    function recoverTokens(address token, address recipient)
        external
        onlyOwner
    {
        require(token != vaultParams.asset, "Vault asset not recoverable");
        require(token != address(this), "Vault share not recoverable");
        require(recipient != address(this), "Recipient cannot be vault");
        require(token != spreadState.currentSpreadToken, "Spread Token not recoverable");

        IERC20(token).safeTransfer(
            recipient,
            IERC20(token).balanceOf(address(this))
        );
    }
}
