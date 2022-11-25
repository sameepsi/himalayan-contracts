// SPDX-License-Identifier: MIT
pragma solidity =0.8.12;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ManualStrikeSelectionCallSpread is Ownable {
    /// @dev Selected strike price
    uint256[] public strikePrices;

    /// @dev Delta for options strike price selection. 1 is 10000 (10**4)
    uint256[] public deltas = [1000, 1000];

    /**
     * @notice Sets the strike price, only callable by the owner
     * @param _strikePrices are the strike prices of the options in the spread
     */
    function setStrikePrice(uint256[] calldata _strikePrices) external onlyOwner {
        strikePrices = _strikePrices;
    }

    /**
     * @notice Gets the strike price satisfying the delta value
     * given the expiry timestamp and whether option is call or put
     * @return newStrikePrice is the strike price of the option (ex: for BTC might be 45000 * 10 ** 8)
     * @return newDelta is the delta of the option given its parameters
     */
    function getStrikePrices(uint256, bool)
        external
        view
        returns (uint256[] memory, uint256[] memory)
    {
        return (strikePrices, deltas);
    }
}
