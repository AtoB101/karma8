// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {EconomyFixture} from "./helpers/EconomyFixture.sol";
import {ContributionNFT} from "../src/nft/ContributionNFT.sol";

contract ContributionNFTTest is EconomyFixture {
    function setUp() public {
        setUpEconomy();
    }

    function test_MintAndSoulbound() public {
        address dev = makeAddr("dev");
        uint256 id = nft.mint(dev, 42, "ipfs://x");
        assertEq(nft.ownerOf(id), dev);
        assertEq(nft.totalWeightOf(dev), 42);

        vm.prank(dev);
        vm.expectRevert(ContributionNFT.Soulbound.selector);
        nft.transferFrom(dev, makeAddr("other"), id);
    }
}