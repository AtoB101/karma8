// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title ContributionNFT
/// @notice Soulbound ERC-721 contribution credential. Non-transferable, wallet-bound.
contract ContributionNFT is ERC721, ReentrancyGuard {
    struct Contribution {
        uint256 weight;
        string uri;
        uint64 mintedAt;
    }

    address public minter; // multisig
    uint256 public nextId;
    mapping(uint256 => Contribution) public contributions;
    mapping(address => uint256) public totalWeightOf;

    event MinterUpdated(address indexed minter);
    event ContributionMinted(uint256 indexed tokenId, address indexed to, uint256 weight);

    error Unauthorized();
    error Soulbound();

    modifier onlyMinter() {
        if (msg.sender != minter) revert Unauthorized();
        _;
    }

    constructor(address minter_) ERC721("Karma Contribution", "KARMA-C") {
        require(minter_ != address(0), "zero");
        minter = minter_;
    }

    function setMinter(address minter_) external onlyMinter {
        require(minter_ != address(0), "zero");
        minter = minter_;
        emit MinterUpdated(minter_);
    }

    function mint(address to, uint256 weight, string calldata uri)
        external
        onlyMinter
        nonReentrant
        returns (uint256 id)
    {
        require(to != address(0) && weight > 0, "bad");
        id = ++nextId;
        contributions[id] = Contribution({weight: weight, uri: uri, mintedAt: uint64(block.timestamp)});
        totalWeightOf[to] += weight;
        _safeMint(to, id);
        emit ContributionMinted(id, to, weight);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return contributions[tokenId].uri;
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        // Allow mint (from=0) and burn (to=0) only; block transfers
        if (from != address(0) && to != address(0)) revert Soulbound();
        return super._update(to, tokenId, auth);
    }
}
