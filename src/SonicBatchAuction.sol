// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

/**
 * @title SonicBatchAuction
 * @notice Production-grade Batch Dutch Auction with Uniform Clearing Price on Sonic.
 * @dev Key Features:
 *      1. Uniform Clearing Price: All winning participants pay the exact same market-clearing price.
 *      2. 100% Lossless Bids: Non-winning bidders receive a 100% full refund with zero fees/penalties.
 *      3. Anti-Sniping Protection: Dynamic countdown extensions if bids arrive in the final window.
 *      4. Anti-Whale Protection: Per-address cumulative bid ceiling.
 *      5. Sonic FeeM Integration: Native hook to register with Sonic's Fee Monetization for 90% gas rebates.
 */
contract SonicBatchAuction {
    // --- Structs ---
    struct Bid {
        uint256 id;
        address bidder;
        uint256 amount;            // Total Native $S deposited
        uint256 maxPricePerToken;  // Maximum willingness to pay (wei of $S per 1e18 token units)
        uint256 timestamp;
        bool claimed;
        bool won;
    }

    // --- State Variables ---
    address public immutable seller;
    address public immutable tokenOffered;
    uint256 public immutable totalTokensOffered;
    uint256 public immutable reservePrice;       // Minimum price per token (wei of $S per 1e18 tokens)
    uint256 public immutable maxBidPerAddress;   // Maximum Native $S deposit allowed per address
    uint256 public immutable antiSnipeWindow;    // Seconds before end that trigger an extension (e.g. 300)
    uint256 public immutable antiSnipeExtension; // Extension duration in seconds (e.g. 300)

    uint256 public auctionStartTime;
    uint256 public auctionEndTime;
    uint256 public feemProjectId;

    bool public settled;
    bool public tokensDeposited;
    bool private locked; // Reentrancy guard

    uint256 public clearingPrice;
    uint256 public totalWinningFunds;
    uint256 public totalTokensSold;
    uint256 public cutoffWinningIndex; // Exclusive upper bound index in sortedBids

    // Bids storage
    Bid[] public bids;
    uint256[] public sortedBidIds; // Bid IDs sorted descending by maxPricePerToken
    mapping(address => uint256) public totalBidByAddress;
    mapping(address => uint256[]) public userBidIds;

    // --- Events ---
    event AuctionInitialized(
        address indexed seller,
        address indexed token,
        uint256 totalTokensOffered,
        uint256 reservePrice,
        uint256 startTime,
        uint256 endTime
    );
    event BidPlaced(
        uint256 indexed bidId,
        address indexed bidder,
        uint256 amount,
        uint256 maxPricePerToken,
        uint256 newEndTime
    );
    event AuctionSettled(
        uint256 clearingPrice,
        uint256 totalFundsRaised,
        uint256 totalTokensSold,
        uint256 winningBidsCount
    );
    event TokensClaimed(address indexed bidder, uint256 indexed bidId, uint256 tokenAmount);
    event RefundClaimed(address indexed bidder, uint256 indexed bidId, uint256 refundAmount);
    event FeeMRegistered(uint256 feemProjectId);

    // --- Modifiers ---
    modifier nonReentrant() {
        require(!locked, "Reentrancy detected");
        locked = true;
        _;
        locked = false;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Only seller permitted");
        _;
    }

    /**
     * @notice Construct and fund the auction with offered tokens
     * @param _tokenOffered Address of the ERC20 token being auctioned
     * @param _totalTokensOffered Total token units offered (in 1e18 base)
     * @param _reservePrice Minimum reserve price per 1e18 token units
     * @param _duration Duration of the auction in seconds
     * @param _maxBidPerAddress Anti-whale cap per address
     * @param _antiSnipeWindow Time window before end that triggers extension (e.g. 300)
     * @param _antiSnipeExtension Seconds added when a late bid arrives (e.g. 300)
     * @param _feemProjectId Sonic Fee Monetization project ID
     */
    constructor(
        address _tokenOffered,
        uint256 _totalTokensOffered,
        uint256 _reservePrice,
        uint256 _duration,
        uint256 _maxBidPerAddress,
        uint256 _antiSnipeWindow,
        uint256 _antiSnipeExtension,
        uint256 _feemProjectId
    ) {
        require(_tokenOffered != address(0), "Invalid token");
        require(_totalTokensOffered > 0, "No tokens offered");
        require(_reservePrice > 0, "Reserve price must be > 0");
        require(_duration > 0, "Duration must be > 0");
        require(_maxBidPerAddress > 0, "Max bid per address must be > 0");

        seller = msg.sender;
        tokenOffered = _tokenOffered;
        totalTokensOffered = _totalTokensOffered;
        reservePrice = _reservePrice;
        maxBidPerAddress = _maxBidPerAddress;
        antiSnipeWindow = _antiSnipeWindow;
        antiSnipeExtension = _antiSnipeExtension;
        feemProjectId = _feemProjectId;

        auctionStartTime = block.timestamp;
        auctionEndTime = block.timestamp + _duration;

        emit AuctionInitialized(
            seller,
            _tokenOffered,
            _totalTokensOffered,
            _reservePrice,
            auctionStartTime,
            auctionEndTime
        );
    }

    /**
     * @notice Seller deposits the offered tokens to activate bidding
     */
    function depositOfferedTokens() external onlySeller {
        require(!tokensDeposited, "Already deposited");
        tokensDeposited = true;
        bool funded = IERC20(tokenOffered).transferFrom(msg.sender, address(this), totalTokensOffered);
        require(funded, "Token deposit failed");
    }

    /**
     * @notice Sonic Fee Monetization (FeeM) official integration
     * @dev Connects this contract to Sonic's Projects' Contracts Registrar
     */
    function registerFeeM() external onlySeller {
        // Sonic FeeM Registrar: 0xDC2B0D2Dd2b7759D97D50db4eabDC36973110830
        (bool success,) = address(0xDC2B0D2Dd2b7759D97D50db4eabDC36973110830).call(
            abi.encodeWithSignature("selfRegister(uint256)", feemProjectId)
        );
        require(success, "FeeM selfRegister failed");
        emit FeeMRegistered(feemProjectId);
    }

    /**
     * @notice Place a bid with Native $S and specify maximum willingness to pay per token
     * @param _maxPricePerToken Max price in wei of $S per 1e18 tokens (must be >= reservePrice)
     * @param _hintIndex Optional index in sortedBidIds where this bid should be inserted (gas optimization)
     */
    function placeBid(uint256 _maxPricePerToken, uint256 _hintIndex) external payable nonReentrant {
        require(tokensDeposited || IERC20(tokenOffered).balanceOf(address(this)) >= totalTokensOffered, "Auction not funded yet");
        require(block.timestamp >= auctionStartTime, "Auction not started");
        require(block.timestamp < auctionEndTime, "Auction ended");
        require(!settled, "Already settled");
        require(msg.value > 0, "Bid value must be > 0");
        require(_maxPricePerToken >= reservePrice, "Max price below reserve");
        require(
            totalBidByAddress[msg.sender] + msg.value <= maxBidPerAddress,
            "Exceeds max bid per address"
        );

        totalBidByAddress[msg.sender] += msg.value;

        uint256 newBidId = bids.length;
        bids.push(Bid({
            id: newBidId,
            bidder: msg.sender,
            amount: msg.value,
            maxPricePerToken: _maxPricePerToken,
            timestamp: block.timestamp,
            claimed: false,
            won: false
        }));
        userBidIds[msg.sender].push(newBidId);

        // Insert into sortedBidIds descending by maxPricePerToken
        _insertSortedBid(newBidId, _maxPricePerToken, _hintIndex);

        // Anti-sniping check
        if (auctionEndTime - block.timestamp < antiSnipeWindow) {
            auctionEndTime = block.timestamp + antiSnipeExtension;
        }

        emit BidPlaced(newBidId, msg.sender, msg.value, _maxPricePerToken, auctionEndTime);
    }

    /**
     * @dev Inserts newBidId into sortedBidIds in descending order of maxPricePerToken
     */
    function _insertSortedBid(uint256 newBidId, uint256 price, uint256 hint) internal {
        uint256 len = sortedBidIds.length;
        if (len == 0) {
            sortedBidIds.push(newBidId);
            return;
        }

        // Validate hint if provided
        if (hint <= len) {
            bool validBefore = (hint == 0) || (bids[sortedBidIds[hint - 1]].maxPricePerToken >= price);
            bool validAfter = (hint == len) || (bids[sortedBidIds[hint]].maxPricePerToken <= price);
            if (validBefore && validAfter) {
                sortedBidIds.push(0);
                for (uint256 i = len; i > hint; i--) {
                    sortedBidIds[i] = sortedBidIds[i - 1];
                }
                sortedBidIds[hint] = newBidId;
                return;
            }
        }

        // Fallback: Linear scan insertion (fast on Sonic EVM for batches)
        uint256 targetIndex = len;
        for (uint256 i = 0; i < len; i++) {
            if (price > bids[sortedBidIds[i]].maxPricePerToken) {
                targetIndex = i;
                break;
            }
        }

        sortedBidIds.push(0);
        for (uint256 i = len; i > targetIndex; i--) {
            sortedBidIds[i] = sortedBidIds[i - 1];
        }
        sortedBidIds[targetIndex] = newBidId;
    }

    /**
     * @notice Calculate estimated uniform clearing price based on current bids
     * @return estClearingPrice The uniform clearing price (wei of $S per 1e18 tokens)
     * @return winningCutoff Index in sortedBidIds (0 to winningCutoff-1 are winning bids)
     * @return winningFunds Total Native $S from winning bids
     * @return tokensSold Total tokens that will be sold
     */
    function calculateClearingPrice() public view returns (
        uint256 estClearingPrice,
        uint256 winningCutoff,
        uint256 winningFunds,
        uint256 tokensSold
    ) {
        uint256 len = sortedBidIds.length;
        if (len == 0) {
            return (reservePrice, 0, 0, 0);
        }

        uint256 cumFunds = 0;
        uint256 bestCutoff = 0;
        uint256 bestClearingPrice = reservePrice;

        for (uint256 i = 0; i < len; i++) {
            Bid storage b = bids[sortedBidIds[i]];
            cumFunds += b.amount;

            // Implied clearing price if bids 0..i all win
            // impliedPrice = (cumFunds * 1e18) / totalTokensOffered
            uint256 impliedPrice = (cumFunds * 1e18) / totalTokensOffered;

            if (impliedPrice <= b.maxPricePerToken) {
                bestCutoff = i + 1;
                bestClearingPrice = impliedPrice >= reservePrice ? impliedPrice : reservePrice;
            } else {
                // If implied price exceeds this bidder's willingness to pay,
                // we cannot expand the winning set further with full fill.
                break;
            }
        }

        if (bestCutoff == 0) {
            return (reservePrice, 0, 0, 0);
        }

        // Calculate actual winning funds & tokens sold
        uint256 finalWinningFunds = 0;
        for (uint256 i = 0; i < bestCutoff; i++) {
            finalWinningFunds += bids[sortedBidIds[i]].amount;
        }

        uint256 sold = (finalWinningFunds * 1e18) / bestClearingPrice;
        if (sold > totalTokensOffered) {
            sold = totalTokensOffered;
        }

        return (bestClearingPrice, bestCutoff, finalWinningFunds, sold);
    }

    /**
     * @notice Settle the auction after end time, finalizing clearing price and payouts
     */
    function settleAuction() external nonReentrant {
        require(block.timestamp >= auctionEndTime, "Auction still ongoing");
        require(!settled, "Already settled");

        settled = true;

        (
            uint256 finalPrice,
            uint256 cutoff,
            uint256 winningFunds,
            uint256 sold
        ) = calculateClearingPrice();

        clearingPrice = finalPrice;
        cutoffWinningIndex = cutoff;
        totalWinningFunds = winningFunds;
        totalTokensSold = sold;

        // Mark all winning bids explicitly
        for (uint256 i = 0; i < cutoff; i++) {
            bids[sortedBidIds[i]].won = true;
        }

        // Payout seller:
        // 1. Transfer winning funds raised in $S
        if (winningFunds > 0) {
            (bool success,) = payable(seller).call{value: winningFunds}("");
            require(success, "Funds transfer to seller failed");
        }

        // 2. Return unsold tokens to seller
        if (sold < totalTokensOffered) {
            uint256 unsold = totalTokensOffered - sold;
            bool success = IERC20(tokenOffered).transfer(seller, unsold);
            require(success, "Token return to seller failed");
        }

        emit AuctionSettled(finalPrice, winningFunds, sold, cutoff);
    }

    /**
     * @notice Check whether a given bid is in the winning set
     */
    function isWinningBid(uint256 bidId) public view returns (bool) {
        if (!settled || bidId >= bids.length) return false;
        return bids[bidId].won;
    }

    /**
     * @notice Claim tokens (if winning) or 100% full refund (if losing)
     * @param bidId ID of the bid to claim
     */
    function claim(uint256 bidId) public nonReentrant {
        require(settled, "Auction not settled yet");
        require(bidId < bids.length, "Invalid bid ID");

        Bid storage b = bids[bidId];
        require(b.bidder == msg.sender, "Not bid owner");
        require(!b.claimed, "Already claimed");

        b.claimed = true;

        if (isWinningBid(bidId)) {
            // Winning bid: receives tokens at the uniform clearing price
            uint256 tokenAmount = (b.amount * 1e18) / clearingPrice;
            bool success = IERC20(tokenOffered).transfer(b.bidder, tokenAmount);
            require(success, "Token transfer failed");

            emit TokensClaimed(b.bidder, bidId, tokenAmount);
        } else {
            // Losing bid: receives 100% full refund with ZERO fee
            (bool success,) = payable(b.bidder).call{value: b.amount}("");
            require(success, "Refund transfer failed");

            emit RefundClaimed(b.bidder, bidId, b.amount);
        }
    }

    /**
     * @notice Convenience function to claim all bids belonging to caller
     */
    function claimAll() external {
        uint256[] storage myBids = userBidIds[msg.sender];
        require(myBids.length > 0, "No bids to claim");
        for (uint256 i = 0; i < myBids.length; i++) {
            uint256 bId = myBids[i];
            if (!bids[bId].claimed) {
                claim(bId);
            }
        }
    }

    /**
     * @notice Get all bid IDs submitted by a specific user
     */
    function getUserBids(address user) external view returns (uint256[] memory) {
        return userBidIds[user];
    }

    /**
     * @notice Total number of bids placed
     */
    function totalBidsCount() external view returns (uint256) {
        return bids.length;
    }

    receive() external payable {}
}
