pragma solidity =0.8.17;

import "./SpreadBaseToken.sol";
import {IController} from "../../interfaces/GammaInterface.sol";

import {ISpreadToken} from "../../interfaces/IHimalayan.sol";


contract SpreadToken is SpreadBaseToken {

    address public immutable GAMMA_CONTROLLER;

    IERC20 public asset;

    IERC20 public underlying;

    address public himalayanVault;

    bool public initialized;

    bool public settled;

    constructor(address gamma) public {
        require(gamma != address(0), "!gamma");
        GAMMA_CONTROLLER = gamma;
    }

    function init(
        string calldata name,
        string calldata symbol,
        address _asset,
        address _underlying
    )
        external
    {
        require(!initialized, "Already initialized");
        require(_asset != address(0), "!asset");
        require(_underlying != address(0), "!asset");

        initialized = true;
        _name = name;
        _symbol = symbol;
        asset = IERC20(_asset);
        underlying = IERC20(_underlying);
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

}