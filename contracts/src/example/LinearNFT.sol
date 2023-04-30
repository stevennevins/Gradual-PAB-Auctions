// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {toDaysWadUnsafe, toWadUnsafe, fromDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";
import {LinkedBidsListLib, LinkedBidsList, Bid} from "src/lib/LinkedBidsListLib.sol";

import {LinearVRGEA} from "src/LinearVRGEA.sol";
import "forge-std/Test.sol";

contract LinearNFT is ERC721, LinearVRGEA {
    /// TODO Implement check minBidIncrease
    ///     - Just need to check head bidInfo before insertion and current bid to insert
    /// TODO Implement minting of the NFTs
    ///     - maybe lazy minting just allocate instorage. Array of structs(startId + quantity).
    using SafeCastLib for uint256;
    using SafeTransferLib for address;
    using LinkedBidsListLib for LinkedBidsList;

    constructor()
        ERC721("NFT", "LINEAR")
        LinearVRGEA(block.timestamp, 1e18, 0.31e18, 1e18)
    {}

    function bid(uint8 amount) external payable {
        require(amount > 0, "Amount 0");
        uint256 unitPrice = msg.value / amount;
        require(unitPrice >= reservePrice, "Bid too low");
        uint256 fillableQuantity = _getFillableQuantity(startTime);
        if (fillableQuantity > 0) _processFillableBids(fillableQuantity);
        bidQueue.insert(msg.sender, amount, unitPrice.safeCastTo88());
    }

    function removeBid() external {
        uint256 fillableQuantity = _getFillableQuantity(startTime);
        if (fillableQuantity > 0) _processFillableBids(fillableQuantity);
        Bid memory bidInfo = bidQueue.bids[msg.sender];
        uint256 refund = bidInfo.quantity * bidInfo.unitPrice;
        bidQueue.remove(msg.sender, bidInfo.quantity);
        msg.sender.safeTransferETH(refund);
    }

    function _processFillableBids(uint256 quantity) internal {
        Bid memory bidInfo = bidQueue.bids[bidQueue.highestBidder];
        totalSold += quantity;

        /// pull from queue while we have remaining quantity
        while (quantity > 0) {
            if (bidInfo.quantity == 0) {
                /// if we run out of bidders in the queue extend the auction
                int256 extensionWad = getTargetSaleTime(
                    toWadUnsafe(totalSold)
                ) - getTargetSaleTime(toWadUnsafe(totalSold - quantity));
                extendedTime += fromDaysWadUnsafe(extensionWad);
                totalSold -= quantity;
                quantity = 0;
            } else if (bidInfo.quantity > quantity) {
                /// if the highestBidder has more quantity than we are trying to settle
                bidQueue.remove(bidQueue.highestBidder, quantity);
                quantity = 0;
            } else {
                /// if the highestBidder had less quantity than we were trying to settle
                quantity -= bidInfo.quantity;
                bidQueue.remove(bidQueue.highestBidder, bidInfo.quantity);
                bidInfo = bidQueue.bids[bidQueue.highestBidder];
            }
        }
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "";
    }
}
