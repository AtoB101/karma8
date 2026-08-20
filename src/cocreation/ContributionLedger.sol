// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ContributionNFT} from "../nft/ContributionNFT.sol";
import {IContributorRegistry} from "../interfaces/IContributorRegistry.sol";
import {ContributorRegistry} from "./ContributorRegistry.sol";
import {CocreationMath} from "../libraries/CocreationMath.sol";
import {KarmaEconomyConstants} from "../libraries/KarmaEconomyConstants.sol";

/// @title ContributionLedger
/// @notice On-chain cocreation contribution events: C = W_base × Q × T, decay, mint gate.
contract ContributionLedger is ReentrancyGuard {
    using CocreationMath for uint256;

    enum EventCode {
        ADAPTER_SHIP,
        SCENE_SPEC,
        VERIFY_RULE,
        TEMPLATE_LIVE,
        DISPUTE_HELP,
        AUDIT_PASS,
        SETTLE_OK,
        ATTEST_OK,
        NEGATIVE_FRAUD,
        NEGATIVE_SYBIL,
        NEGATIVE_MALICIOUS_DISPUTE
    }

    enum Quality {
        Submitted, // 0.25
        Accepted, // 0.70
        TestnetLive, // 1.00
        ProdGmv, // 1.25
        Default30d // 1.50
    }

    struct EventRecord {
        address wallet;
        IContributorRegistry.Role role;
        EventCode code;
        bytes32 track;
        uint256 wBase;
        uint256 qBps;
        uint256 tBps;
        uint256 cEvent;
        uint64 createdAt;
        bool accepted;
        bool negative;
        bool minted;
        string uri;
    }

    ContributorRegistry public immutable registry;
    ContributionNFT public nft;
    address public governance;
    address public accepter; // SCENE_OWNER ops / oracle (can be msig)

    mapping(EventCode => int256) public wBaseOf; // signed to allow negatives
    mapping(Quality => uint256) public qualityBps;
    mapping(bytes32 => uint256) public trackBps; // default 10000 if unset
    uint256 public mintThreshold;
    uint256 public nextEventId;

    mapping(uint256 => EventRecord) public events;
    mapping(address => uint256[]) internal _eventIdsOf;
    mapping(address => uint256) public lifetimeAcceptedWeight;
    mapping(address => uint256) public mintedWeightOf;
    mapping(address => int256) public negativePenalty; // absolute penalty points (no decay)

    event GovernanceUpdated(address indexed governance);
    event AccepterUpdated(address indexed accepter);
    event NftUpdated(address indexed nft);
    event EventSubmitted(uint256 indexed eventId, address indexed wallet, EventCode code, uint256 cEvent);
    event EventAccepted(uint256 indexed eventId, address indexed wallet, uint256 cEvent);
    event EventRejected(uint256 indexed eventId);
    event Minted(address indexed wallet, uint256 weight, uint256 tokenId);

    error Unauthorized();
    error BadInput();
    error NotBound();
    error BadState();
    error BelowThreshold();

    modifier onlyGovernance() {
        if (msg.sender != governance) revert Unauthorized();
        _;
    }

    modifier onlyAccepter() {
        if (msg.sender != accepter && msg.sender != governance) revert Unauthorized();
        _;
    }

    constructor(address registry_, address nft_, address governance_, address accepter_) {
        require(
            registry_ != address(0) && nft_ != address(0) && governance_ != address(0) && accepter_ != address(0),
            "zero"
        );
        registry = ContributorRegistry(registry_);
        nft = ContributionNFT(nft_);
        governance = governance_;
        accepter = accepter_;
        mintThreshold = KarmaEconomyConstants.MINT_THRESHOLD_WEIGHT;
        _initDefaults();
    }

    function setGovernance(address g) external onlyGovernance {
        require(g != address(0), "zero");
        governance = g;
        emit GovernanceUpdated(g);
    }

    function setAccepter(address a) external onlyGovernance {
        require(a != address(0), "zero");
        accepter = a;
        emit AccepterUpdated(a);
    }

    function setNft(address nft_) external onlyGovernance {
        require(nft_ != address(0), "zero");
        nft = ContributionNFT(nft_);
        emit NftUpdated(nft_);
    }

    function setMintThreshold(uint256 t) external onlyGovernance {
        mintThreshold = t;
    }

    function setWBase(EventCode code, int256 w) external onlyGovernance {
        wBaseOf[code] = w;
    }

    function setQualityBps(Quality q, uint256 bps) external onlyGovernance {
        require(bps > 0 && bps <= 20_000, "bps");
        qualityBps[q] = bps;
    }

    function setTrackBps(bytes32 track, uint256 bps) external onlyGovernance {
        require(bps > 0 && bps <= 20_000, "bps");
        trackBps[track] = bps;
    }

    /// @notice Submit a contribution event (pending until accept).
    function submit(
        EventCode code,
        IContributorRegistry.Role role,
        bytes32 track,
        Quality quality,
        string calldata uri
    ) external returns (uint256 eventId) {
        return _submit(msg.sender, code, role, track, quality, uri);
    }

    function submitFor(
        address wallet,
        EventCode code,
        IContributorRegistry.Role role,
        bytes32 track,
        Quality quality,
        string calldata uri
    ) external onlyAccepter returns (uint256 eventId) {
        return _submit(wallet, code, role, track, quality, uri);
    }

    /// @notice Accept event: locks Q/T, credits lifetime weight (or penalty).
    function accept(uint256 eventId) external onlyAccepter {
        EventRecord storage e = events[eventId];
        if (e.wallet == address(0) || e.accepted) revert BadState();
        if (!registry.isActive(e.wallet)) revert NotBound();

        // High-risk tracks cannot be auto-accepted as TestnetLive/Prod without Default30d/Prod path —
        // accepter is trusted; enforce: if track multiplier is high_risk (1.5x) and quality > Accepted, require SCENE_OWNER role on accepter wallet or governance.
        if (trackBps[e.track] >= 15_000 && e.qBps > qualityBps[Quality.Accepted]) {
            if (msg.sender != governance && !registry.hasRole(msg.sender, IContributorRegistry.Role.SCENE_OWNER)) {
                revert Unauthorized();
            }
        }

        e.accepted = true;
        if (e.negative) {
            negativePenalty[e.wallet] += int256(e.cEvent);
        } else {
            lifetimeAcceptedWeight[e.wallet] += e.cEvent;
        }
        emit EventAccepted(eventId, e.wallet, e.cEvent);
    }

    function reject(uint256 eventId) external onlyAccepter {
        EventRecord storage e = events[eventId];
        if (e.wallet == address(0) || e.accepted || e.minted) revert BadState();
        delete events[eventId];
        emit EventRejected(eventId);
    }

    /// @notice Mint soulbound NFT weight from unminted accepted contribution (threshold gated).
    function mintPending(address wallet, string calldata uri) external nonReentrant returns (uint256 tokenId) {
        if (!registry.isActive(wallet)) revert NotBound();
        if (!registry.hasRole(wallet, IContributorRegistry.Role.BUILDER)
            && !registry.hasRole(wallet, IContributorRegistry.Role.EXPERT)) {
            revert NotBound();
        }
        uint256 pending = pendingMintWeight(wallet);
        if (pending < mintThreshold) revert BelowThreshold();
        if (msg.sender != wallet && msg.sender != accepter && msg.sender != governance) revert Unauthorized();

        mintedWeightOf[wallet] += pending;
        // Mark positive accepted unminted events as minted (accounting by aggregate pending)
        uint256[] storage ids = _eventIdsOf[wallet];
        for (uint256 i = 0; i < ids.length; i++) {
            EventRecord storage e = events[ids[i]];
            if (e.accepted && !e.negative && !e.minted) e.minted = true;
        }

        tokenId = nft.mint(wallet, pending, uri);
        emit Minted(wallet, pending, tokenId);
    }

    function pendingMintWeight(address wallet) public view returns (uint256) {
        uint256 life = lifetimeAcceptedWeight[wallet];
        uint256 minted = mintedWeightOf[wallet];
        return life > minted ? life - minted : 0;
    }

    /// @notice Active contribution with decay; negatives applied without decay.
    function activeContribution(address wallet) public view returns (uint256) {
        uint256 total;
        uint256[] storage ids = _eventIdsOf[wallet];
        for (uint256 i = 0; i < ids.length; i++) {
            EventRecord storage e = events[ids[i]];
            if (!e.accepted || e.negative) continue;
            uint256 age = block.timestamp - uint256(e.createdAt);
            total += CocreationMath.applyDecay(e.cEvent, age);
        }
        int256 pen = negativePenalty[wallet];
        if (pen > 0 && uint256(pen) >= total) return 0;
        if (pen > 0) total -= uint256(pen);
        return total;
    }

    function eventIdsOf(address wallet) external view returns (uint256[] memory) {
        return _eventIdsOf[wallet];
    }

    function quoteCEvent(EventCode code, bytes32 track, Quality quality) public view returns (uint256) {
        int256 w = wBaseOf[code];
        if (w <= 0) return 0;
        uint256 q = qualityBps[quality];
        uint256 t = trackBps[track];
        if (t == 0) t = 10_000;
        return CocreationMath.cEvent(uint256(w), q, t);
    }

    function _submit(
        address wallet,
        EventCode code,
        IContributorRegistry.Role role,
        bytes32 track,
        Quality quality,
        string calldata uri
    ) internal returns (uint256 eventId) {
        if (!registry.isActive(wallet)) revert NotBound();
        if (!registry.hasRole(wallet, role)) revert NotBound();

        int256 wSigned = wBaseOf[code];
        bool negative = wSigned < 0;
        uint256 wAbs = negative ? uint256(-wSigned) : uint256(wSigned);
        if (wAbs == 0) revert BadInput();

        // Spec §8.3: accepted-only quality cannot exceed 0.70 until live/prod path —
        // submit may request higher Q but accept enforces; at submit we store requested Q.
        uint256 q = qualityBps[quality];
        uint256 t = trackBps[track];
        if (t == 0) t = 10_000;
        // Tracks boost requires bound track when T > 1.0
        if (t > 10_000) {
            bytes32[] memory tr = registry.tracksOf(wallet);
            bool ok;
            for (uint256 i = 0; i < tr.length; i++) {
                if (tr[i] == track) {
                    ok = true;
                    break;
                }
            }
            if (!ok) t = 10_000;
        }

        uint256 c = CocreationMath.cEvent(wAbs, q, t);
        eventId = ++nextEventId;
        events[eventId] = EventRecord({
            wallet: wallet,
            role: role,
            code: code,
            track: track,
            wBase: wAbs,
            qBps: q,
            tBps: t,
            cEvent: c,
            createdAt: uint64(block.timestamp),
            accepted: false,
            negative: negative,
            minted: false,
            uri: uri
        });
        _eventIdsOf[wallet].push(eventId);
        emit EventSubmitted(eventId, wallet, code, c);
    }

    function _initDefaults() internal {
        wBaseOf[EventCode.ADAPTER_SHIP] = 500;
        wBaseOf[EventCode.SCENE_SPEC] = 800;
        wBaseOf[EventCode.VERIFY_RULE] = 600;
        wBaseOf[EventCode.TEMPLATE_LIVE] = 300;
        wBaseOf[EventCode.DISPUTE_HELP] = 400;
        wBaseOf[EventCode.AUDIT_PASS] = 1000;
        wBaseOf[EventCode.SETTLE_OK] = 20;
        wBaseOf[EventCode.ATTEST_OK] = 20;
        wBaseOf[EventCode.NEGATIVE_FRAUD] = -1000;
        wBaseOf[EventCode.NEGATIVE_SYBIL] = -500;
        wBaseOf[EventCode.NEGATIVE_MALICIOUS_DISPUTE] = -100;

        qualityBps[Quality.Submitted] = 2500;
        qualityBps[Quality.Accepted] = 7000;
        qualityBps[Quality.TestnetLive] = 10_000;
        qualityBps[Quality.ProdGmv] = 12_500;
        qualityBps[Quality.Default30d] = 15_000;

        trackBps[keccak256("daily_commerce")] = 10_000;
        trackBps[keccak256("digital")] = 10_000;
        trackBps[keccak256("b2b")] = 12_000;
        trackBps[keccak256("professional")] = 12_000;
        trackBps[keccak256("high_risk")] = 15_000;
    }
}
