// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IRewardPool} from "../interfaces/IRewardPool.sol";
import {IKarmaCoreView} from "../interfaces/IKarmaCoreView.sol";
import {IContributorRegistry} from "../interfaces/IContributorRegistry.sol";
import {ContributionNFT} from "../nft/ContributionNFT.sol";

/// @title DeveloperRewardPool
/// @notice Receives 40% treasury USDC; distributes by monthly GMV share + contribution NFT weight.
contract DeveloperRewardPool is IRewardPool, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdc;
    IKarmaCoreView public karmaCore;
    ContributionNFT public contributionNft;
    IContributorRegistry public registry;
    address public treasury;
    bool public revenueMode;

    uint256 public epochReward;
    uint64 public epochStart;
    uint64 public epochEnd;
    uint256 public constant GMV_WEIGHT_BPS = 7000;
    uint256 public constant NFT_WEIGHT_BPS = 3000;

    address[] public developers;
    mapping(address => bool) public isDeveloper;
    mapping(address => uint256) public claimableOf;
    mapping(address => uint256) public lifetimeClaimed;
    /// @notice Virtual share points accrued while revenueMode=false (cold-start pending_share).
    mapping(address => uint256) public pendingPoints;
    uint256 public totalPendingPoints;

    event RewardNotified(uint256 amount);
    event EpochSettled(uint64 start, uint64 end, uint256 reward);
    event PendingEpochSettled(uint64 start, uint64 end, uint256 totalPoints);
    event Claimed(address indexed developer, uint256 amount);
    event DeveloperRegistered(address indexed developer);
    event RevenueModeUpdated(bool enabled);
    event RegistryUpdated(address indexed registry);

    error Unauthorized();
    error RevenueOff();
    error NotBuilder();

    modifier onlyTreasury() {
        if (msg.sender != treasury) revert Unauthorized();
        _;
    }

    constructor(address usdc_, address treasury_, address karmaCore_, address nft_) {
        require(usdc_ != address(0) && treasury_ != address(0), "zero");
        usdc = IERC20(usdc_);
        treasury = treasury_;
        karmaCore = IKarmaCoreView(karmaCore_);
        contributionNft = ContributionNFT(nft_);
        epochStart = uint64(block.timestamp);
        epochEnd = uint64(block.timestamp + 30 days);
    }

    function setTreasury(address t) external onlyTreasury {
        require(t != address(0), "zero");
        treasury = t;
    }

    function setRevenueMode(bool enabled) external onlyTreasury {
        revenueMode = enabled;
        emit RevenueModeUpdated(enabled);
    }

    function setKarmaCore(address core) external onlyTreasury {
        karmaCore = IKarmaCoreView(core);
    }

    function setContributionNft(address nft) external onlyTreasury {
        contributionNft = ContributionNFT(nft);
    }

    function setRegistry(address registry_) external onlyTreasury {
        registry = IContributorRegistry(registry_);
        emit RegistryUpdated(registry_);
    }

    function registerDeveloper(address developer) external {
        require(developer != address(0), "zero");
        if (address(registry) != address(0)) {
            if (!registry.isActive(developer) || !registry.hasRole(developer, IContributorRegistry.Role.BUILDER)) {
                revert NotBuilder();
            }
        }
        if (!isDeveloper[developer]) {
            isDeveloper[developer] = true;
            developers.push(developer);
            emit DeveloperRegistered(developer);
        }
    }

    function notifyReward(uint256 amount) external override onlyTreasury {
        if (!revenueMode) revert RevenueOff();
        if (amount == 0) return;
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        epochReward += amount;
        emit RewardNotified(amount);
    }

    /// @notice Settle monthly epoch using karma-core GMV views + NFT weights.
    function settleEpoch() external nonReentrant {
        if (!revenueMode) revert RevenueOff();
        require(block.timestamp >= epochEnd, "epoch");
        uint256 reward = epochReward;
        epochReward = 0;

        uint64 fromTs = epochStart;
        uint64 toTs = epochEnd;
        (uint256[] memory gmvs, uint256[] memory nfts, uint256 totalGmv, uint256 totalNft) =
            _collectWeights(fromTs, toTs);

        if (reward > 0 && developers.length > 0) {
            for (uint256 i = 0; i < developers.length; i++) {
                uint256 share = _shareOf(reward, gmvs[i], nfts[i], totalGmv, totalNft);
                if (share > 0) claimableOf[developers[i]] += share;
            }
        }

        epochStart = uint64(block.timestamp);
        epochEnd = uint64(block.timestamp + 30 days);
        emit EpochSettled(fromTs, toTs, reward);
    }

    /// @notice Cold-start: accrue pending share points without USDC (revenueMode may be false).
    function settlePendingEpoch() external nonReentrant {
        require(block.timestamp >= epochEnd, "epoch");
        uint64 fromTs = epochStart;
        uint64 toTs = epochEnd;
        uint256 notional = 1e18;
        (uint256[] memory gmvs, uint256[] memory nfts, uint256 totalGmv, uint256 totalNft) =
            _collectWeights(fromTs, toTs);

        uint256 added;
        for (uint256 i = 0; i < developers.length; i++) {
            uint256 pts = _shareOf(notional, gmvs[i], nfts[i], totalGmv, totalNft);
            if (pts > 0) {
                pendingPoints[developers[i]] += pts;
                added += pts;
            }
        }
        totalPendingPoints += added;
        epochStart = uint64(block.timestamp);
        epochEnd = uint64(block.timestamp + 30 days);
        emit PendingEpochSettled(fromTs, toTs, added);
    }

    /// @notice Preview USDC share for `reward` using current epoch GMV/NFT weights (works when revenue off).
    function previewEpochShare(address developer, uint256 reward)
        external
        view
        returns (uint256 share, uint256 gmv, uint256 nftWeight)
    {
        gmv = address(karmaCore) == address(0) ? 0 : karmaCore.getDeveloperGmv(developer, epochStart, epochEnd);
        nftWeight = address(contributionNft) == address(0) ? 0 : contributionNft.totalWeightOf(developer);
        uint256 n = developers.length;
        uint256 totalGmv;
        uint256 totalNft;
        for (uint256 i = 0; i < n; i++) {
            address d = developers[i];
            totalGmv += address(karmaCore) == address(0) ? 0 : karmaCore.getDeveloperGmv(d, epochStart, epochEnd);
            totalNft += address(contributionNft) == address(0) ? 0 : contributionNft.totalWeightOf(d);
        }
        share = _shareOf(reward, gmv, nftWeight, totalGmv, totalNft);
    }

    function claim() external nonReentrant {
        if (!revenueMode) revert RevenueOff();
        uint256 amount = claimableOf[msg.sender];
        require(amount > 0, "zero");
        claimableOf[msg.sender] = 0;
        lifetimeClaimed[msg.sender] += amount;
        usdc.safeTransfer(msg.sender, amount);
        emit Claimed(msg.sender, amount);
    }

    function developerCount() external view returns (uint256) {
        return developers.length;
    }

    function _collectWeights(uint64 fromTs, uint64 toTs)
        internal
        view
        returns (uint256[] memory gmvs, uint256[] memory nfts, uint256 totalGmv, uint256 totalNft)
    {
        uint256 n = developers.length;
        gmvs = new uint256[](n);
        nfts = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            address d = developers[i];
            uint256 g = address(karmaCore) == address(0) ? 0 : karmaCore.getDeveloperGmv(d, fromTs, toTs);
            uint256 w = address(contributionNft) == address(0) ? 0 : contributionNft.totalWeightOf(d);
            gmvs[i] = g;
            nfts[i] = w;
            totalGmv += g;
            totalNft += w;
        }
    }

    function _shareOf(uint256 reward, uint256 gmv, uint256 nftWeight, uint256 totalGmv, uint256 totalNft)
        internal
        pure
        returns (uint256 share)
    {
        if (reward == 0) return 0;
        if (totalGmv > 0) {
            share += (reward * GMV_WEIGHT_BPS * gmv) / (totalGmv * 10_000);
        }
        if (totalNft > 0) {
            share += (reward * NFT_WEIGHT_BPS * nftWeight) / (totalNft * 10_000);
        }
    }
}
