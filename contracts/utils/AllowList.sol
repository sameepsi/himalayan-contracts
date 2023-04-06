// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract AllowList is Ownable {
    mapping(address => bool) private _allowList;
    uint256 private _allowListCount;
    bool public activateList;

    event AddressAdded(address indexed addr);
    event AddressRemoved(address indexed addr);
    event ActivationFlagUpdated(bool flag);

    function updateActivationFlag(bool status) external onlyOwner {
        activateList = status;
        emit ActivationFlagUpdated(status);
    }

    function add(address[] calldata addrs) external onlyOwner {
        for (uint256 i = 0; i < addrs.length; i++) {
            address addr = addrs[i];
            require(!_allowList[addr], "AllowList: Address already present");
            _allowList[addr] = true;
            _allowListCount += 1;
            emit AddressAdded(addr);
        }
    }

    function remove(address addr) external onlyOwner {
        if (!_allowList[addr]) {
            revert("AllowList: Address not found");
        }
        _allowList[addr] = false;
        _allowListCount -= 1;
        emit AddressRemoved(addr);
    }

    function isAllowed(address addr) external view returns (bool) {
        if (!activateList) {
            return true;
        }
        return _allowList[addr];
    }

    function getCount() external view returns (uint256) {
        return _allowListCount;
    }
}
