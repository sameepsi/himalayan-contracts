// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Vault} from "./Vault.sol";
import {ShareMath} from "./ShareMath.sol";
import {IStrikeSelectionSpread, ISpreadToken} from "../interfaces/IHimalayan.sol";
import {GnosisAuction} from "./GnosisAuction.sol";
import {
    IOtokenFactory,
    IOtoken,
    IController,
    IMarginCalculator,
    GammaTypes
} from "../interfaces/GammaInterface.sol";
import {IERC20Detailed} from "../interfaces/IERC20Detailed.sol";
import {IGnosisAuction} from "../interfaces/IGnosisAuction.sol";
import {SupportsNonCompliantERC20} from "./SupportsNonCompliantERC20.sol";
import {IOptionsPremiumPricer} from "../interfaces/IHimalayan.sol";

library VaultLifecycleSpread {
    using SupportsNonCompliantERC20 for IERC20;
    using Address for address;
    using Clones for address;

    struct CloseParams {
        address OTOKEN_FACTORY;
        address USDC;
        address[] currentSpread;
        uint256 delay;
        address strikeSelection;
        uint256 premiumDiscount;
        address SPREAD_TOKEN_IMPL;
    }

    // Number of weeks per year = 52.142857 weeks * FEE_MULTIPLIER = 52142857
    // Dividing by weeks per year requires doing (num * FEE_MULTIPLIER) / WEEKS_PER_YEAR
    uint256 internal constant WEEKS_PER_YEAR = 52142857;

    /**
     * @notice Sets the next spread for the vault, and calculates its premium for the auction
     * @param closeParams is the struct with details on previous spread and strike selection details
     * @param vaultParams is the struct with vault general data
     * @param vaultState is the struct with vault accounting state
     * @return spread addresses of the new short and long options
     * @return strikePrices is the strike prices of the options in spread
     * @return deltas is the deltas of the new options in the spread
     */
    function commitAndClose(
        CloseParams calldata closeParams,
        Vault.VaultParams storage vaultParams,
        Vault.VaultState storage vaultState
    )
        external
        returns (
            address[] memory spread,
            uint256[] memory strikePrices,
            uint256[] memory deltas,
            address spreadToken
        )
    {
        uint256 expiry = getNextExpiry(closeParams.currentSpread.length > 0 ? closeParams.currentSpread[0]:address(0));

        IStrikeSelectionSpread selection =
            IStrikeSelectionSpread(closeParams.strikeSelection);

        bool isPut = vaultParams.isPut;
        address underlying = vaultParams.underlying;
        address asset = vaultParams.asset;

        (strikePrices, deltas) = selection.getStrikePrices(expiry, isPut);

        require(strikePrices.length == deltas.length, "Invalid Data");
        for (uint256 i = 0; i < strikePrices.length; i++) {
            require(strikePrices[i] != 0, "!strikePrice");
        }


        // retrieve address if option already exists, or deploy it
        spread = getOrDeployOtokens(
            closeParams,
            vaultParams,
            underlying,
            asset,
            strikePrices,
            expiry,
            isPut
        );

        Vault.SpreadTokenInfo memory spreadTokenInfo;
        spreadTokenInfo.strikePrices = strikePrices;
        spreadTokenInfo.strike = closeParams.USDC;
        spreadTokenInfo.asset = asset;
        spreadTokenInfo.underlying = underlying;
        spreadTokenInfo.expiry = expiry;
        spreadTokenInfo.isPut = isPut;

        spreadToken = deploySpreadToken(
            closeParams.SPREAD_TOKEN_IMPL,
            spreadTokenInfo
        );

        return (spread, strikePrices, deltas, spreadToken);
    }

    function deploySpreadToken(
        address impl,
        Vault.SpreadTokenInfo memory spreadTokenInfo
    )
        private
        returns(address)
    {

        address instance = impl.clone();
        ISpreadToken(instance).init(spreadTokenInfo);

        return instance;
    }

    /**
     * @notice Verify the otoken has the correct parameters to prevent vulnerability to opyn contract changes
     * @param otokenAddress is the address of the otoken
     * @param vaultParams is the struct with vault general data
     * @param collateralAsset is the address of the collateral asset
     * @param USDC is the address of usdc
     * @param delay is the delay between commitAndClose and rollToNextOption
     */
    function verifyOtoken(
        address otokenAddress,
        Vault.VaultParams storage vaultParams,
        address collateralAsset,
        address USDC,
        uint256 delay
    ) private view {
        require(otokenAddress != address(0), "!otokenAddress");

        IOtoken otoken = IOtoken(otokenAddress);
        require(otoken.isPut() == vaultParams.isPut, "Type mismatch");
        require(
            otoken.underlyingAsset() == vaultParams.underlying,
            "Wrong underlyingAsset"
        );
        require(
            otoken.collateralAsset() == collateralAsset,
            "Wrong collateralAsset"
        );

        // we just assume all options use USDC as the strike
        require(otoken.strikeAsset() == USDC, "strikeAsset != USDC");

        uint256 readyAt = block.timestamp  + delay;
        require(otoken.expiryTimestamp() >= readyAt, "Expiry before delay");
    }

    /**
     * @param decimals is the decimals of the asset
     * @param totalBalance is the vaults total balance of the asset
     * @param currentShareSupply is the supply of the shares invoked with totalSupply()
     * @param lastQueuedWithdrawAmount is the total amount queued for withdrawals
     * @param performanceFee is the perf fee percent to charge on premiums
     * @param managementFee is the management fee percent to charge on the AUM
     * @param currentQueuedWithdrawShares is amount of queued withdrawals from the current round
     */
    struct RolloverParams {
        uint256 decimals;
        uint256 totalBalance;
        uint256 currentShareSupply;
        uint256 lastQueuedWithdrawAmount;
        uint256 performanceFee;
        uint256 managementFee;
        uint256 currentQueuedWithdrawShares;
    }

    /**
     * @notice Calculate the shares to mint, new price per share, and
      amount of funds to re-allocate as collateral for the new round
     * @param vaultState is the storage variable vaultState passed from RibbonVault
     * @param params is the rollover parameters passed to compute the next state
     * @return newLockedAmount is the amount of funds to allocate for the new round
     * @return queuedWithdrawAmount is the amount of funds set aside for withdrawal
     * @return newPricePerShare is the price per share of the new round
     * @return mintShares is the amount of shares to mint from deposits
     * @return performanceFeeInAsset is the performance fee charged by vault
     * @return totalVaultFee is the total amount of fee charged by vault
     */
    function rollover(
        Vault.VaultState storage vaultState,
        RolloverParams calldata params
    )
        external
        view
        returns (
            uint256 newLockedAmount,
            uint256 queuedWithdrawAmount,
            uint256 newPricePerShare,
            uint256 mintShares,
            uint256 performanceFeeInAsset,
            uint256 totalVaultFee
        )
    {
        uint256 currentBalance = params.totalBalance;
        uint256 pendingAmount = vaultState.totalPending;
        // Total amount of queued withdrawal shares from previous rounds (doesn't include the current round)
        uint256 lastQueuedWithdrawShares = vaultState.queuedWithdrawShares;

        // Deduct older queued withdraws so we don't charge fees on them
        uint256 balanceForVaultFees =
            currentBalance - params.lastQueuedWithdrawAmount;

        {
            (performanceFeeInAsset, , totalVaultFee) = VaultLifecycleSpread
                .getVaultFees(
                balanceForVaultFees,
                vaultState.lastLockedAmount,
                vaultState.totalPending,
                params.performanceFee,
                params.managementFee
            );
        }

        // Take into account the fee
        // so we can calculate the newPricePerShare
        currentBalance = currentBalance - totalVaultFee;

        {
            newPricePerShare = ShareMath.pricePerShare(
                params.currentShareSupply - lastQueuedWithdrawShares,
                currentBalance - params.lastQueuedWithdrawAmount,
                pendingAmount,
                params.decimals
            );

            queuedWithdrawAmount = params.lastQueuedWithdrawAmount +
                ShareMath.sharesToAsset(
                    params.currentQueuedWithdrawShares,
                    newPricePerShare,
                    params.decimals
                );

            // After closing the short, if the options expire in-the-money
            // vault pricePerShare would go down because vault's asset balance decreased.
            // This ensures that the newly-minted shares do not take on the loss.
            mintShares = ShareMath.assetToShares(
                pendingAmount,
                newPricePerShare,
                params.decimals
            );
        }

        return (
            currentBalance - queuedWithdrawAmount, // new locked balance subtracts the queued withdrawals
            queuedWithdrawAmount,
            newPricePerShare,
            mintShares,
            performanceFeeInAsset,
            totalVaultFee
        );
    }

    /**
     * @notice Creates the actual Opyn short position by depositing collateral and minting otokens
     * @param gammaController is the address of the opyn controller contract
     * @param marginPool is the address of the opyn margin contract which holds the collateral
     * @param spread Spread oTokens
     * @param depositAmount is the amount of collateral to deposit
     * @param newVault whether to create new vault or not
     * @param spreadToken Spread Token
     * @return mintAmount spreadToken mint amount
     * @return collateralUsed collateral amount used to create spread
     */
    function createSpread(
        address gammaController,
        address marginPool,
        address[] calldata spread,
        uint256 depositAmount,
        address spreadToken,
        bool newVault
    ) public returns (uint256 mintAmount, uint256 collateralUsed) {

        // An otoken's collateralAsset is the vault's `asset`
        // So in the context of performing Opyn short operations we call them collateralAsset
        // Assuming both oTokens in the spread has same collateral
        IOtoken oToken = IOtoken(spread[0]);
        address collateralAsset = oToken.collateralAsset();
        {
            uint256 collateralDecimals =
            uint256(IERC20Detailed(collateralAsset).decimals());

            if (oToken.isPut()) {
                // For minting puts, there will be instances where the full depositAmount will not be used for minting.
                // This is because of an issue with precision.
                //
                // For ETH put options, we are calculating the mintAmount (10**8 decimals) using
                // the depositAmount (10**18 decimals), which will result in truncation of decimals when scaling down.
                // As a result, there will be tiny amounts of dust left behind in the Opyn vault when minting put otokens.
                //
                // For simplicity's sake, we do not refund the dust back to the address(this) on minting otokens.
                // We retain the dust in the vault so the calling contract can withdraw the
                // actual locked amount + dust at settlement.
                //
                // To test this behavior, we can console.log
                // MarginCalculatorInterface(0x7A48d10f372b3D7c60f6c9770B91398e4ccfd3C7).getExcessCollateral(vault)
                // to see how much dust (or excess collateral) is left behind.
                mintAmount = (
                    depositAmount
                    * (10**Vault.OTOKEN_DECIMALS)
                    * (10**18) // we use 10**18 to give extra precision
                ) / (oToken.strikePrice() * (10**(10 + collateralDecimals)));
            } else {
                mintAmount = depositAmount;

                if (collateralDecimals > 8) {
                    uint256 scaleBy = 10**(collateralDecimals - 8); // oTokens have 8 decimals
                    if (mintAmount > scaleBy) {
                        mintAmount = depositAmount / (scaleBy); // scale down from 10**18 to 10**8
                    }
                }
            }
        }

        {
            // double approve to fix non-compliant ERC20s
            IERC20 collateralToken = IERC20(collateralAsset);
            collateralToken.safeApproveNonCompliant(marginPool, depositAmount);

            if (newVault) {
                IController controller = IController(gammaController);
                uint256 vaultId =
                    (controller.getAccountVaultCounter(address(this)));
                vaultId = vaultId + 1;

                IController.ActionArgs[] memory actions =
                    new IController.ActionArgs[](3);

                actions[0] = IController.ActionArgs(
                    IController.ActionType.OpenVault,
                    address(this), // owner
                    address(this), // receiver
                    address(0), // asset, otoken
                    vaultId, // vaultId
                    0, // amount
                    0, //index
                    "" //data
                );

                actions[1] = IController.ActionArgs(
                    IController.ActionType.DepositCollateral,
                    address(this), // owner
                    address(this), // address to transfer from
                    collateralAsset, // deposited asset
                    vaultId, // vaultId
                    depositAmount, // amount
                    0, //index
                    "" //data
                );

                actions[2] = IController.ActionArgs(
                    IController.ActionType.MintShortOption,
                    address(this), // owner
                    address(this), // address to transfer to
                    spread[0], // short option address
                    vaultId, // vaultId
                    mintAmount, // amount
                    0, //index
                    "" //data
                );

                controller.operate(actions);
            }

            else {
                IController controller = IController(gammaController);
                uint256 vaultId =
                    (controller.getAccountVaultCounter(address(this)));
                IController.ActionArgs[] memory actions =
                    new IController.ActionArgs[](2);

                actions[0] = IController.ActionArgs(
                    IController.ActionType.DepositCollateral,
                    address(this), // owner
                    address(this), // address to transfer from
                    collateralAsset, // deposited asset
                    vaultId, // vaultId
                    depositAmount, // amount
                    0, //index
                    "" //data
                );

                actions[1] = IController.ActionArgs(
                    IController.ActionType.MintShortOption,
                    address(this), // owner
                    address(this), // address to transfer to
                    spread[0], // short option address
                    vaultId, // vaultId
                    mintAmount, // amount
                    0, //index
                    "" //data
                );

                controller.operate(actions);
            }


        }

        _mintSpread(
            gammaController,
            marginPool,
            spread,
            mintAmount,
            spreadToken
        );

        collateralUsed = _depositAndWithdrawCollateral(
            gammaController,
            marginPool,
            collateralAsset,
            depositAmount,
            spread,
            mintAmount
        );

        return (mintAmount, collateralUsed);
    }

    function _mintSpread(
        address gammaController,
        address marginPool,
        address[] memory spread,
        uint256 mintAmount,
        address spreadToken
    )
        private
    {
        IController controller = IController(gammaController);
        IERC20 shortOption= IERC20(spread[0]);
        shortOption.safeApproveNonCompliant(marginPool, mintAmount);

        IController.ActionArgs[] memory actions =
            new IController.ActionArgs[](2);

        actions[0] = IController.ActionArgs(
            IController.ActionType.DepositLongOption,
            spreadToken, // vault owner
            address(this), // deposit from this address
            spread[0], // collateral otoken
            1, // vaultId
            mintAmount, // amount
            0, // index
            "" // data
        );

        actions[1] = IController.ActionArgs(
          IController.ActionType.MintShortOption,
          spreadToken, // vault owner
          address(this), // mint to this address
          spread[1], // otoken
          1, // vaultId
          mintAmount, // amount
          0, // index
          "" // data
        );

        controller.operate(actions);
    }

    function _depositAndWithdrawCollateral(
        address gammaController,
        address marginPool,
        address collateralAsset,
        uint256 collateralDeposited,
        address[] memory spread,
        uint256 mintAmount
    )
        private
        returns(uint256 collateralUsed)
    {
        IController controller = IController(gammaController);
        uint256 vaultId =
            (controller.getAccountVaultCounter(address(this)));

        IMarginCalculator calculator = IMarginCalculator(controller.calculator());

        IERC20 longOption = IERC20(spread[1]);
        longOption.safeApproveNonCompliant(marginPool, mintAmount);

        IController.ActionArgs[] memory actions =
            new IController.ActionArgs[](1);

        actions[0] = IController.ActionArgs(
            IController.ActionType.DepositLongOption,
            address(this), // vault owner
            address(this), // deposit from this address
            spread[1], // LONG otoken
            vaultId, // vaultId
            mintAmount, // amount
            0, // index
            "" // data
        );

        controller.operate(actions);

        (GammaTypes.MarginVault memory vault, uint256 typeVault, ) = controller.getVaultWithDetails(address(this), vaultId);
        (uint256 excessCollateral, bool isValidVault) = calculator.getExcessCollateral(vault, typeVault);

        actions[0] = IController.ActionArgs(
          IController.ActionType.WithdrawCollateral,
          address(this), // vault owner
          address(this), // mint to this address
          collateralAsset, // otoken
          vaultId, // vaultId
          excessCollateral, // amount
          0, // index
          "" // data
        );

        controller.operate(actions);

        return (collateralDeposited - excessCollateral);
    }

    /**
     * @notice Calculates the performance and management fee for this week's round
     * @param currentBalance is the balance of funds held on the vault after closing short
     * @param lastLockedAmount is the amount of funds locked from the previous round
     * @param pendingAmount is the pending deposit amount
     * @param performanceFeePercent is the performance fee pct.
     * @param managementFeePercent is the management fee pct.
     * @return performanceFeeInAsset is the performance fee
     * @return managementFeeInAsset is the management fee
     * @return vaultFee is the total fees
     */
    function getVaultFees(
        uint256 currentBalance,
        uint256 lastLockedAmount,
        uint256 pendingAmount,
        uint256 performanceFeePercent,
        uint256 managementFeePercent
    )
        internal
        pure
        returns (
            uint256 performanceFeeInAsset,
            uint256 managementFeeInAsset,
            uint256 vaultFee
        )
    {
        // At the first round, currentBalance=0, pendingAmount>0
        // so we just do not charge anything on the first round
        uint256 lockedBalanceSansPending =
            currentBalance > pendingAmount
                ? currentBalance - pendingAmount
                : 0;

        uint256 _performanceFeeInAsset;
        uint256 _managementFeeInAsset;
        uint256 _vaultFee;

        // Take performance fee and management fee ONLY if difference between
        // last week and this week's vault deposits, taking into account pending
        // deposits and withdrawals, is positive. If it is negative, last week's
        // option expired ITM past breakeven, and the vault took a loss so we
        // do not collect performance fee for last week
        if (lockedBalanceSansPending > lastLockedAmount) {
            _performanceFeeInAsset = performanceFeePercent > 0
                ? ((lockedBalanceSansPending - lastLockedAmount) * performanceFeePercent)/ (100 * Vault.FEE_MULTIPLIER)
                : 0;
            _managementFeeInAsset = managementFeePercent > 0
                ? (lockedBalanceSansPending * managementFeePercent) / (100 * Vault.FEE_MULTIPLIER)
                : 0;

            _vaultFee = _performanceFeeInAsset + _managementFeeInAsset;
        }

        return (_performanceFeeInAsset, _managementFeeInAsset, _vaultFee);
    }

    /**
     * @notice Either retrieves the option tokens if they already exists, or deploys them
     * @param closeParams is the struct with details on previous option and strike selection details
     * @param vaultParams is the struct with vault general data
     * @param underlying is the address of the underlying asset of the option
     * @param collateralAsset is the address of the collateral asset of the option
     * @param strikePrices strike prices of the options to be minted
     * @param expiry is the expiry timestamp of the option
     * @param isPut is whether the option is a put
     * @return spread address of the option
     */
    function getOrDeployOtokens(
        CloseParams calldata closeParams,
        Vault.VaultParams storage vaultParams,
        address underlying,
        address collateralAsset,
        uint256[] memory strikePrices,
        uint256 expiry,
        bool isPut
    ) internal returns (address[] memory) {
        IOtokenFactory factory = IOtokenFactory(closeParams.OTOKEN_FACTORY);
        address[] memory spread = new address[](strikePrices.length);

        for (uint8 i = 0; i < strikePrices.length; i++) {
            spread[i] = getOrDeployOToken(
                closeParams.OTOKEN_FACTORY,
                underlying,
                closeParams.USDC,
                collateralAsset,
                strikePrices[i],
                expiry,
                isPut
            );
            verifyOtoken(
                spread[i],
                vaultParams,
                collateralAsset,
                closeParams.USDC,
                closeParams.delay
            );

        }
        return spread;
    }


    /**
     * @notice Close the existing short otoken position. Currently this implementation is simple.
     * It closes the most recent vault opened by the contract. This assumes that the contract will
     * only have a single vault open at any given time. Since calling `_closeShort` deletes vaults by
     calling SettleVault action, this assumption should hold.
     * @param gammaController is the address of the opyn controller contract
     * @param spreadToken Token which holds other vault of the strategy
     * @return amount of collateral redeemed from the vault
     */
    function settleSpread(address gammaController, address spreadToken) external returns (uint256) {
        IController controller = IController(gammaController);

        // gets the currently active vault ID
        uint256 vaultID = controller.getAccountVaultCounter(address(this));

        GammaTypes.Vault memory vault =
            controller.getVault(address(this), vaultID);

        require(vault.shortOtokens.length > 0, "No short");

        // An otoken's collateralAsset is the vault's `asset`
        // So in the context of performing Opyn short operations we call them collateralAsset
        IERC20 collateralToken = IERC20(vault.collateralAssets[0]);

        // The short position has been previously closed, or all the otokens have been burned.
        // So we return early.
        if (address(collateralToken) == address(0)) {
            return 0;
        }

        // This is equivalent to doing IERC20(vault.asset).balanceOf(address(this))
        uint256 startCollateralBalance =
            collateralToken.balanceOf(address(this));

        // If it is after expiry, we need to settle the short position using the normal way
        // Delete the vault and withdraw all remaining collateral from the vault
        IController.ActionArgs[] memory actions =
            new IController.ActionArgs[](1);

        actions[0] = IController.ActionArgs(
            IController.ActionType.SettleVault,
            address(this), // owner
            address(this), // address to transfer to
            address(0), // not used
            vaultID, // vaultId
            0, // not used
            0, // not used
            "" // not used
        );

        controller.operate(actions);

        uint256 endCollateralBalance = collateralToken.balanceOf(address(this));

        ISpreadToken(spreadToken).settleVault();
        ISpreadToken(spreadToken).burnAndClaim();

        return endCollateralBalance - startCollateralBalance;
    }

    function getOrDeployOToken(
        address _factory,
        address _underlyingAsset,
        address _strikeAsset,
        address _collateralAsset,
        uint256 _strikePrice,
        uint256 _expiry,
        bool _isPut

    ) private returns (address) {
        IOtokenFactory factory = IOtokenFactory(_factory);

        address otokenFromFactory =
            factory.getOtoken(
                _underlyingAsset,
                _strikeAsset,
                _collateralAsset,
                _strikePrice,
                _expiry,
                _isPut
            );

        if (otokenFromFactory != address(0)) {
            return otokenFromFactory;
        }

        address otoken =
            factory.createOtoken(
                _underlyingAsset,
                _strikeAsset,
                _collateralAsset,
                _strikePrice,
                _expiry,
                _isPut
            );

        return otoken;
    }

    /**
     * @notice Starts the gnosis auction
     * @param auctionDetails is the struct with all the custom parameters of the auction
     * @return the auction id of the newly created auction
     */
    function startAuction(GnosisAuction.AuctionDetails calldata auctionDetails)
        external
        returns (uint256)
    {
        return GnosisAuction.startAuction(auctionDetails);
    }

    /**
     * @notice Verify the constructor params satisfy requirements
     * @param owner is the owner of the vault with critical permissions
     * @param feeRecipient is the address to recieve vault performance and management fees
     * @param performanceFee is the perfomance fee pct.
     * @param tokenName is the name of the token
     * @param tokenSymbol is the symbol of the token
     * @param _vaultParams is the struct with vault general data
     */
    function verifyInitializerParams(
        address owner,
        address keeper,
        address feeRecipient,
        uint256 performanceFee,
        uint256 managementFee,
        string calldata tokenName,
        string calldata tokenSymbol,
        Vault.VaultParams calldata _vaultParams
    ) external pure {
        require(owner != address(0), "!owner");
        require(keeper != address(0), "!keeper");
        require(feeRecipient != address(0), "!feeRecipient");
        require(
            performanceFee < 100 * Vault.FEE_MULTIPLIER,
            "performanceFee >= 100%"
        );
        require(
            managementFee < 100 * Vault.FEE_MULTIPLIER,
            "managementFee >= 100%"
        );
        require(bytes(tokenName).length > 0, "!tokenName");
        require(bytes(tokenSymbol).length > 0, "!tokenSymbol");

        require(_vaultParams.asset != address(0), "!asset");
        require(_vaultParams.underlying != address(0), "!underlying");
        require(_vaultParams.minimumSupply > 0, "!minimumSupply");
        require(_vaultParams.cap > 0, "!cap");
        require(
            _vaultParams.cap > _vaultParams.minimumSupply,
            "cap has to be higher than minimumSupply"
        );
    }

    /**
     * @notice Gets the next option expiry timestamp
     * @param currentSpread is the otoken address that the vault is currently writing
     */
    function getNextExpiry(address currentSpread)
        internal
        view
        returns (uint256)
    {
        /**if (currentSpread == address(0)) {
            return getNextDay(block.timestamp);
        }
        uint256 currentExpiry = IOtoken(currentSpread).expiryTimestamp();

        // After options expiry if no options are written for >1 week
        // We need to give the ability continue writing options
        if (block.timestamp > currentExpiry + 1 days) {
            return getNextDay(block.timestamp);
        }
        return getNextDay(currentExpiry);*/


        if (currentSpread == address(0)) {
            return getNextFriday(block.timestamp);
        }
        uint256 currentExpiry = IOtoken(currentSpread).expiryTimestamp();

        // After options expiry if no options are written for >1 week
        // We need to give the ability continue writing options
        if (block.timestamp > currentExpiry + 1 days) {
            return getNextFriday(block.timestamp);
        }
        return getNextFriday(currentExpiry);

    }

    /**
     * @notice Gets the next options expiry timestamp
     * @param timestamp is the expiry timestamp of the current option
     * Reference: https://codereview.stackexchange.com/a/33532
     * Examples:
     * getNextFriday(week 1 thursday) -> week 1 friday
     * getNextFriday(week 1 friday) -> week 2 friday
     * getNextFriday(week 1 saturday) -> week 2 friday
     */
    function getNextFriday(uint256 timestamp) internal pure returns (uint256) {
        // dayOfWeek = 0 (sunday) - 6 (saturday)
        uint256 dayOfWeek = ((timestamp / 1 days) + 4) % 7;
        uint256 nextFriday = timestamp + ((7 + 5 - dayOfWeek) % 7) * 1 days;
        uint256 friday8am = nextFriday - (nextFriday % (24 hours)) + (8 hours);

        // If the passed timestamp is day=Friday hour>8am, we simply increment it by a week to next Friday
        if (timestamp >= friday8am) {
            friday8am += 7 days;
        }
        return friday8am;
    }

    //TODO: REMOVE THIS
    /**function getNextDay(uint256 timestamp) internal pure returns (uint256) {
        // dayOfWeek = 0 (sunday) - 6 (saturday)
        uint256 nextDay = timestamp + 1 days;
        uint256 nextDay8am = nextDay - (nextDay % (24 hours)) + (8 hours);

        // If the passed timestamp is day=Friday hour>8am, we simply increment it by a week to next Friday
        if (timestamp >= nextDay8am) {
            nextDay8am += 1 days;
        }
        return nextDay8am;
    }*/
}
