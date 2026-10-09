// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SonicWinWinAuction (LEGACY / EXPERIMENTAL PROTOTYPE)
 * @notice Deprecated experimental prototype exploring gamified "Bid-to-Earn" incentives.
 * @dev Retained in `legacy/` for historical research and comparative game-theoretic reference.
 *      WARNING: NOT intended for production token launches due to shill-bidding attack vectors.
 *      For production fair launches and token distributions, use:
 *      - `SonicBatchAuction.sol` (Mode 1: Uniform Clearing Price, 100% lossless, anti-sniping)
 *      - `SonicDecayingAuction.sol` (Mode 2: Continuous Time-Decaying Dutch, instant buy)
 */
contract SonicWinWinAuction {
    address public immutable devTreasury;
    uint256 public feemProjectId;

    // Auction configuration
    uint256 public constant MIN_INCREMENT_PERCENT = 10; // New bid must be at least +10% higher
    uint256 public constant OUTBID_REWARD_PERCENT = 5;  // Previous bidder gets +5% bonus
    uint256 public constant DEV_FEE_PERCENT = 2;        // Platform fee 2%
    uint256 public constant ANTI_SNIPE_WINDOW = 30;     // Extend timer by 30s if bid in last 30s
    uint256 public constant DEFAULT_ROUND_DURATION = 3 minutes; // Fast rounds for Sonic's speed

    // State variables
    uint256 public currentRound;
    bool private locked; // Reentrancy protection

    struct Round {
        uint256 roundId;
        uint256 startTime;
        uint256 endTime;
        address highestBidder;
        uint256 highestBid;
        uint256 prizePot;
        bool settled;
        uint256 totalBidsCount;
    }

    mapping(uint256 => Round) public rounds;

    // Events
    event RoundStarted(uint256 indexed roundId, uint256 startTime, uint256 endTime);
    event BidPlaced(uint256 indexed roundId, address indexed bidder, uint256 bidAmount, uint256 newEndTime);
    event OutbidRewardPaid(uint256 indexed roundId, address indexed outbidBidder, uint256 refundAmount, uint256 rewardAmount);
    event RoundSettled(uint256 indexed roundId, address indexed winner, uint256 prizeAwarded);
    event FeeMRegistered(uint256 feemProjectId);

    modifier noReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    modifier onlyDev() {
        require(msg.sender == devTreasury, "Not authorized");
        _;
    }

    constructor(uint256 _feemProjectId) payable {
        devTreasury = msg.sender;
        feemProjectId = _feemProjectId;
        
        // Start Round 1
        _startNewRound(msg.value);
    }

    /**
     * @notice Official Sonic Fee Monetization (FeeM) integration
     * @dev Connects this contract to Sonic's Projects' Contracts Registrar
     */
    function registerFeeM() external onlyDev {
        // Sonic Mainnet / Testnet FeeM Registrar: 0xDC2B0D2Dd2b7759D97D50db4eabDC36973110830
        (bool success,) = address(0xDC2B0D2Dd2b7759D97D50db4eabDC36973110830).call(
            abi.encodeWithSignature("selfRegister(uint256)", feemProjectId)
        );
        require(success, "FeeM selfRegister failed");
        emit FeeMRegistered(feemProjectId);
    }

    /**
     * @notice Set or update FeeM Project ID
     */
    function setFeemProjectId(uint256 _projectId) external onlyDev {
        feemProjectId = _projectId;
    }

    /**
     * @notice Calculate the minimum acceptable bid for the active round
     */
    function getMinNextBid() public view returns (uint256) {
        Round storage r = rounds[currentRound];
        if (r.highestBid == 0) {
            return 0.1 ether; // Initial base bid (0.1 S)
        }
        return r.highestBid + (r.highestBid * MIN_INCREMENT_PERCENT / 100);
    }

    /**
     * @notice Place a bid in the current active round
     */
    function placeBid() external payable noReentrant {
        Round storage r = rounds[currentRound];
        require(block.timestamp < r.endTime, "Round expired; settle first");
        require(!r.settled, "Round already settled");

        uint256 minRequired = getMinNextBid();
        require(msg.value >= minRequired, "Bid below minimum required increment");

        address previousBidder = r.highestBidder;
        uint256 previousBid = r.highestBid;

        // 1. If there was a previous bidder, pay them 100% refund + 5% profit bonus
        if (previousBidder != address(0)) {
            uint256 rewardBonus = (msg.value * OUTBID_REWARD_PERCENT) / 100;
            uint256 totalPayout = previousBid + rewardBonus;

            (bool refundSuccess,) = payable(previousBidder).call{value: totalPayout}("");
            require(refundSuccess, "Refund transfer failed");

            emit OutbidRewardPaid(currentRound, previousBidder, previousBid, rewardBonus);
        }

        // 2. Protocol fee to Dev Treasury (2%)
        uint256 devFee = (msg.value * DEV_FEE_PERCENT) / 100;
        (bool feeSuccess,) = payable(devTreasury).call{value: devFee}("");
        require(feeSuccess, "Dev fee transfer failed");

        // 3. Remainder value accumulates in the prize pot
        // When previous bidder was paid (previousBid + 5%), net added to pot is:
        // msg.value - (previousBid + 5%) - 2% fee. But previousBid was already in the contract.
        // So contract balance changes by: +msg.value - totalPayout - devFee.
        r.highestBidder = msg.sender;
        r.highestBid = msg.value;
        r.totalBidsCount++;
        r.prizePot = address(this).balance;

        // 4. Anti-sniping: extend timer by 30 seconds if bid placed near the end
        if (r.endTime - block.timestamp < ANTI_SNIPE_WINDOW) {
            r.endTime = block.timestamp + ANTI_SNIPE_WINDOW;
        }

        emit BidPlaced(currentRound, msg.sender, msg.value, r.endTime);
    }

    /**
     * @notice Settle the expired round and award the prize pot to the winner
     */
    function settleAndNextRound() external noReentrant {
        Round storage r = rounds[currentRound];
        require(block.timestamp >= r.endTime, "Round not ended yet");
        require(!r.settled, "Already settled");

        r.settled = true;
        address winner = r.highestBidder;
        uint256 prize = address(this).balance;

        // If there was a valid bidder, transfer the entire accumulated pot to the winner
        if (winner != address(0) && prize > 0) {
            (bool success,) = payable(winner).call{value: prize}("");
            require(success, "Prize transfer failed");
            emit RoundSettled(currentRound, winner, prize);
        }

        // Start next round immediately
        _startNewRound(0);
    }

    function _startNewRound(uint256 seedPot) internal {
        currentRound++;
        uint256 start = block.timestamp;
        uint256 end = start + DEFAULT_ROUND_DURATION;

        rounds[currentRound] = Round({
            roundId: currentRound,
            startTime: start,
            endTime: end,
            highestBidder: address(0),
            highestBid: 0,
            prizePot: seedPot,
            settled: false,
            totalBidsCount: 0
        });

        emit RoundStarted(currentRound, start, end);
    }

    /**
     * @notice Get current round details in one call
     */
    function getCurrentRoundInfo() external view returns (
        uint256 roundId,
        uint256 timeRemaining,
        address topBidder,
        uint256 topBid,
        uint256 prizePot,
        uint256 minNextBid,
        uint256 bidCount
    ) {
        Round storage r = rounds[currentRound];
        uint256 remaining = block.timestamp >= r.endTime ? 0 : r.endTime - block.timestamp;
        return (
            currentRound,
            remaining,
            r.highestBidder,
            r.highestBid,
            address(this).balance,
            getMinNextBid(),
            r.totalBidsCount
        );
    }

    receive() external payable {}
}
