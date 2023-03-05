pragma solidity =0.8.17;

import "./SpreadBaseToken.sol";
import {IController} from "../../interfaces/GammaInterface.sol";

import {ISpreadToken} from "../../interfaces/IHimalayan.sol";
import {BokkyPooBahsDateTimeLibrary} from "../../vendor/BokkyPooBahsDateTimeLibrary.sol";
import {
ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
Strings
} from "@openzeppelin/contracts/utils/Strings.sol";
import {Vault} from "../../libraries/Vault.sol";

contract SpreadToken is SpreadBaseToken {

    address public immutable GAMMA_CONTROLLER;

    IERC20 public asset;

    IERC20 public underlyingAsset;

    uint256 public expiryTimestamp;

    bool public isPut;

    address public himalayanVault;

    bool public initialized;

    bool public settled;

    uint256 private constant STRIKE_PRICE_SCALE = 1e8;

    uint256 private constant STRIKE_PRICE_DIGITS = 8;

    constructor(address gamma) public {
        require(gamma != address(0), "!gamma");
        GAMMA_CONTROLLER = gamma;
    }

    function init(
        Vault.SpreadTokenInfo memory spreadTokenInfo
    )
        external
    {
        require(!initialized, "Already initialized");
        require(spreadTokenInfo.strike != address(0), "!strike");
        require(spreadTokenInfo.asset != address(0), "!asset");
        require(spreadTokenInfo.underlying != address(0), "!underlying");
        require(spreadTokenInfo.expiry > block.timestamp, "!expiry");

        initialized = true;
        generateNameAndSymbol(spreadTokenInfo);
        _name = spreadTokenInfo.tokenName;
        _symbol = spreadTokenInfo.tokenSymbol;
        asset = IERC20(spreadTokenInfo.asset);
        underlyingAsset = IERC20(spreadTokenInfo.underlying);
        expiryTimestamp = spreadTokenInfo.expiry;
        isPut = spreadTokenInfo.isPut;
        himalayanVault = _msgSender();

        IController.ActionArgs[] memory actions =
            new IController.ActionArgs[](1);

        actions[0] = IController.ActionArgs(
            IController.ActionType.OpenVault,
            address(this), // owner
            address(0), // receiver
            address(0), // asset
            1, // vaultId
            0, // amount
            0, //index
            "" //data
        );

        IController controller = IController(GAMMA_CONTROLLER);

        controller.operate(actions);

        controller.setOperator(himalayanVault, true);
    }

    function mint(uint256 amount) external {
        require(_msgSender() == himalayanVault, "Unauthorized access");

        _mint(_msgSender(), amount);
    }

    function settleVault() external {
        require(_msgSender() == himalayanVault, "Unauthorized access");
        settled = true;

        IController.ActionArgs[] memory actions =
            new IController.ActionArgs[](1);

        actions[0] = IController.ActionArgs(
            IController.ActionType.SettleVault,
            address(this), // owner
            address(this), // address to transfer to
            address(0), // not used
            1, // vaultId
            0, // not used
            0, // not used
            "" // not used
        );

        IController controller = IController(GAMMA_CONTROLLER);
        controller.operate(actions);
    }

    function burnAndClaim() external {
        require(settled, "!settled");

        uint256 tokenBalance = balanceOf(_msgSender());
        uint256 totalBalance = totalSupply();
        uint256 receivedAmount = (tokenBalance * (asset.balanceOf(address(this)))) / (totalBalance);
        _burn(_msgSender(), tokenBalance);
        asset.transfer(_msgSender(), receivedAmount);
    }


    /**
     * @notice generates the name and symbol for an option
     * @dev this function uses a named return variable to avoid the stack-too-deep error
     *  tokenName (ex: ETHUSDC 05-September-2020 200 Put USDC Collateral)
     *  tokenSymbol (ex: oETHUSDC-05SEP20-200P) //Himalayan MATIC Call Spread Vault-03MAR23-1.38-1.5
     */
    function generateNameAndSymbol(
        Vault.SpreadTokenInfo memory spreadTokenInfo
    ) internal {
        spreadTokenInfo.displayStrikePrice1 = _getDisplayedStrikePrice(spreadTokenInfo.strikePrices[0]);
        spreadTokenInfo.displayStrikePrice2 = _getDisplayedStrikePrice(spreadTokenInfo.strikePrices[1]);
        spreadTokenInfo.strikeSymbol = ERC20Upgradeable(spreadTokenInfo.strike).symbol();
        spreadTokenInfo.underlyingSymbol = ERC20Upgradeable(spreadTokenInfo.underlying).symbol();

        {
            string memory collateralSymbol = ERC20Upgradeable(spreadTokenInfo.asset).symbol();

            // convert expiry to a readable string
            (uint256 year, uint256 month, uint256 day) = BokkyPooBahsDateTimeLibrary.timestampToDate(spreadTokenInfo.expiry);

            // get option type string
            (string memory typeSymbol, string memory typeFull) = _getOptionType(spreadTokenInfo.isPut);

            //get option month string
            (string memory monthSymbol, string memory monthFull) = _getMonth(month);

            // concatenated name string: WMATIC Call Spread 05-March-2023 1.2-1.5 WMATIC Collateral
            spreadTokenInfo.tokenName = string(
                abi.encodePacked(
                    spreadTokenInfo.underlyingSymbol,
                    spreadTokenInfo.strikeSymbol,
                    " ",
                    typeFull,
                    " Spread ",
                    _uintTo2Chars(day),
                    "-",
                    monthFull,
                    "-",
                    Strings.toString(year),
                    " ",
                    spreadTokenInfo.displayStrikePrice1,
                    "-",
                    spreadTokenInfo.displayStrikePrice2,
                    " ",
                    collateralSymbol,
                    " Collateral"
                )
            );

            // concatenated symbol string: oWMATICUSDC/WMATIC-07MAR23-1.2-1.5C
            spreadTokenInfo.tokenSymbol = string(
                abi.encodePacked(
                    "o",
                    spreadTokenInfo.underlyingSymbol,
                    spreadTokenInfo.strikeSymbol,
                    "/",
                    collateralSymbol,
                    "-",
                    _uintTo2Chars(day),
                    monthSymbol,
                    _uintTo2Chars(year),
                    "-",
                    spreadTokenInfo.displayStrikePrice1,
                    "-",
                    spreadTokenInfo.displayStrikePrice2,
                    typeSymbol
                )
            );
        }
    }

    /**
     * @dev convert strike price scaled by 1e8 to human readable number string
     * @param _strikePrice strike price scaled by 1e8
     * @return strike price string
     */
    function _getDisplayedStrikePrice(uint256 _strikePrice) internal pure returns (string memory) {

        uint256 remainder = _strikePrice % STRIKE_PRICE_SCALE;
        uint256 quotient = _strikePrice/STRIKE_PRICE_SCALE;
        string memory quotientStr = Strings.toString(quotient);

        if (remainder == 0) return quotientStr;

        uint256 trailingZeroes;
        while ((remainder % 10) == 0) {
            remainder = remainder / 10;
            trailingZeroes += 1;
        }

        // pad the number with "1 + starting zeroes"
        remainder += 10**(STRIKE_PRICE_DIGITS - trailingZeroes);

        string memory tmpStr = Strings.toString(remainder);
        tmpStr = _slice(tmpStr, 1, 1 + STRIKE_PRICE_DIGITS - trailingZeroes);

        string memory completeStr = string(abi.encodePacked(quotientStr, ".", tmpStr));
        return completeStr;
    }

    /**
     * @dev return a representation of a number using 2 characters, adds a leading 0 if one digit, uses two trailing digits if a 3 digit number
     * @return 2 characters that corresponds to a number
     */
    function _uintTo2Chars(uint256 number) internal pure returns (string memory) {
        if (number > 99) number = number % 100;
        string memory str = Strings.toString(number);
        if (number < 10) {
            return string(abi.encodePacked("0", str));
        }
        return str;
    }

    /**
     * @dev return string representation of option type
     * @return shortString a 1 character representation of option type (P or C)
     * @return longString a full length string of option type (Put or Call)
     */
    function _getOptionType(bool _isPut) internal pure returns (string memory shortString, string memory longString) {
        if (_isPut) {
            return ("P", "Put");
        } else {
            return ("C", "Call");
        }
    }

    /**
     * @dev cut string s into s[start:end]
     * @param _s the string to cut
     * @param _start the starting index
     * @param _end the ending index (excluded in the substring)
     */
    function _slice(
        string memory _s,
        uint256 _start,
        uint256 _end
    ) internal pure returns (string memory) {
        bytes memory a = new bytes(_end - _start);
        for (uint256 i = 0; i < _end - _start; i++) {
            a[i] = bytes(_s)[_start + i];
        }
        return string(a);
    }

    /**
     * @dev return string representation of a month
     * @return shortString a 3 character representation of a month (ex: SEP, DEC, etc)
     * @return longString a full length string of a month (ex: September, December, etc)
     */
    function _getMonth(uint256 _month) internal pure returns (string memory shortString, string memory longString) {
        if (_month == 1) {
            return ("JAN", "January");
        } else if (_month == 2) {
            return ("FEB", "February");
        } else if (_month == 3) {
            return ("MAR", "March");
        } else if (_month == 4) {
            return ("APR", "April");
        } else if (_month == 5) {
            return ("MAY", "May");
        } else if (_month == 6) {
            return ("JUN", "June");
        } else if (_month == 7) {
            return ("JUL", "July");
        } else if (_month == 8) {
            return ("AUG", "August");
        } else if (_month == 9) {
            return ("SEP", "September");
        } else if (_month == 10) {
            return ("OCT", "October");
        } else if (_month == 11) {
            return ("NOV", "November");
        } else {
            return ("DEC", "December");
        }
    }

}
