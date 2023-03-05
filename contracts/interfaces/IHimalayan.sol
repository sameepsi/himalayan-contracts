// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;
import {Vault} from "../libraries/Vault.sol";

interface IHimalayan {
    function deposit(uint256 amount) external;

    function depositETH() external payable;

    function cap() external view returns (uint256);

    function depositFor(uint256 amount, address creditor) external;

    function vaultParams() external view returns (Vault.VaultParams memory);
}

interface IStrikeSelectionSpread {
    function getStrikePrices(uint256 expiryTimestamp, bool isPut)
        external
        view
        returns (uint256[] memory, uint256[] memory);

    function delta() external view returns (uint256);
}

interface IOptionsPremiumPricer {
    function getPremium(
        uint256 strikePrice,
        uint256 timeToExpiry,
        bool isPut
    ) external view returns (uint256);

    function getPremiumInStables(
        uint256 strikePrice,
        uint256 timeToExpiry,
        bool isPut
    ) external view returns (uint256);

    function getOptionDelta(
        uint256 spotPrice,
        uint256 strikePrice,
        uint256 volatility,
        uint256 expiryTimestamp
    ) external view returns (uint256 delta);

    function getUnderlyingPrice() external view returns (uint256);

    function priceOracle() external view returns (address);

    function volatilityOracle() external view returns (address);

    function optionId() external view returns (bytes32);
}

interface ISpreadToken {

    function init(
        Vault.SpreadTokenInfo memory spreadTokenInfo
    )
        external;

    function mint(uint256 amount) external;

    function settleVault() external;

    function burnAndClaim() external;
}
