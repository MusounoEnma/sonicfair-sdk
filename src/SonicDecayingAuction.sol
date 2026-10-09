// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

/**
 * @title SonicDecayingAuction
 * @notice Continuous Time-Decaying Dutch Auction (Flash & Gaming Sale Engine) on Sonic.
 * @dev Key Features:
 *      1. Smooth Continuous Price Decay: Price drops automatically every second/block from startPrice down to floorPrice.
 *      2. Instant Execution: Buyers execute at the current real-time market price P(t).
 *      3. Automatic Change Refund: If a buyer sends more $S than remaining inventory costs, excess $S is refunded instantly.
 *      4. Early Sell-Out: Automatically concludes as soon as all tokens are absorbed.
 *      5. Sonic FeeM Integration: Native hook for 90% gas fee monetization rebates.
 */
contract SonicDecayingAuction {
    address public immutable seller;
    address public immutable tokenOffered;
    uint256 public immutable totalTokensOffered;
    uint256 public immutable startPrice;  // Ceiling price (wei of $S per 1e18 tokens)
    uint256 public immutable floorPrice;  // Floor reserve price (wei of $S per 1e18 tokens)
    uint256 public immutable startTime;
    uint256 public immutable endTime;
    uint256 public immutable duration;
    uint256 public feemProjectId;

    uint256 public remainingTokens;
    uint256 public totalFundsRaised;
    uint256 public totalTokensSold;
    uint256 public buyersCount;

    bool public tokensDeposited;
    bool public auctionClosed;
    bool private locked;

    event AuctionInitialized(
        address indexed seller,
        address indexed token,
        uint256 totalTokensOffered,
        uint256 startPrice,
        uint256 floorPrice,
        uint256 startTime,
        uint256 endTime
    );
    event TokensPurchased(
        address indexed buyer,
        uint256 amountPaid,
        uint256 tokensBought,
        uint256 currentPrice,
        uint256 refundChange
    );
    event AuctionClosed(uint256 totalFundsRaised, uint256 totalTokensSold, uint256 unsoldReturned);
    event FeeMRegistered(uint256 feemProjectId);

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

    constructor(
        address _tokenOffered,
        uint256 _totalTokensOffered,
        uint256 _startPrice,
        uint256 _floorPrice,
        uint256 _duration,
        uint256 _feemProjectId
    ) {
        require(_tokenOffered != address(0), "Invalid token");
        require(_totalTokensOffered > 0, "No tokens offered");
        require(_startPrice > _floorPrice, "Start price must be > floor price");
        require(_floorPrice > 0, "Floor price must be > 0");
        require(_duration > 0, "Duration must be > 0");

        seller = msg.sender;
        tokenOffered = _tokenOffered;
        totalTokensOffered = _totalTokensOffered;
        remainingTokens = _totalTokensOffered;
        startPrice = _startPrice;
        floorPrice = _floorPrice;
        duration = _duration;
        startTime = block.timestamp;
        endTime = block.timestamp + _duration;
        feemProjectId = _feemProjectId;

        emit AuctionInitialized(
            seller,
            _tokenOffered,
            _totalTokensOffered,
            _startPrice,
            _floorPrice,
            startTime,
            endTime
        );
    }

    /**
     * @notice Seller deposits the offered tokens to activate the auction
     */
    function depositOfferedTokens() external onlySeller {
        require(!tokensDeposited, "Already deposited");
        tokensDeposited = true;
        bool funded = IERC20(tokenOffered).transferFrom(msg.sender, address(this), totalTokensOffered);
        require(funded, "Token deposit failed");
    }

    /**
     * @notice Sonic Fee Monetization (FeeM) official integration
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
     * @notice Calculate the continuous real-time decaying price at current block.timestamp
     * @return currentPrice Current price in wei of $S per 1e18 token units
     */
    function getCurrentPrice() public view returns (uint256 currentPrice) {
        if (block.timestamp <= startTime) {
            return startPrice;
        }
        if (block.timestamp >= endTime) {
            return floorPrice;
        }

        uint256 elapsed = block.timestamp - startTime;
        uint256 priceDrop = ((startPrice - floorPrice) * elapsed) / duration;
        return startPrice - priceDrop;
    }

    /**
     * @notice Buy tokens at the current real-time decaying price
     */
    function buyTokens() external payable nonReentrant {
        require(tokensDeposited || IERC20(tokenOffered).balanceOf(address(this)) >= remainingTokens, "Auction not funded yet");
        require(block.timestamp >= startTime, "Auction not started");
        require(block.timestamp <= endTime, "Auction ended");
        require(!auctionClosed, "Auction already closed");
        require(remainingTokens > 0, "Sold out");
        require(msg.value > 0, "No funds sent");

        uint256 curPrice = getCurrentPrice();

        // Calculate maximum tokens that can be purchased with msg.value
        // tokens = (msg.value * 1e18) / curPrice
        uint256 desiredTokens = (msg.value * 1e18) / curPrice;
        require(desiredTokens > 0, "Insufficient value for minimum token unit");

        uint256 tokensToDeliver = desiredTokens;
        uint256 actualCost = msg.value;
        uint256 refundChange = 0;

        // If desired tokens exceed remaining inventory, partial fill and refund change
        if (tokensToDeliver > remainingTokens) {
            tokensToDeliver = remainingTokens;
            actualCost = (tokensToDeliver * curPrice) / 1e18;
            refundChange = msg.value - actualCost;
        }

        remainingTokens -= tokensToDeliver;
        totalTokensSold += tokensToDeliver;
        totalFundsRaised += actualCost;
        buyersCount++;

        // Deliver tokens
        bool success = IERC20(tokenOffered).transfer(msg.sender, tokensToDeliver);
        require(success, "Token transfer failed");

        // Refund change if any
        if (refundChange > 0) {
            (bool refundSuccess,) = payable(msg.sender).call{value: refundChange}("");
            require(refundSuccess, "Refund change failed");
        }

        emit TokensPurchased(msg.sender, actualCost, tokensToDeliver, curPrice, refundChange);

        // Auto-close if sold out
        if (remainingTokens == 0) {
            _closeAuction();
        }
    }

    /**
     * @notice Settle and close auction, sending proceeds and unsold tokens to seller
     */
    function closeAuction() external nonReentrant {
        require(block.timestamp >= endTime || remainingTokens == 0, "Auction still ongoing");
        require(!auctionClosed, "Already closed");
        _closeAuction();
    }

    function _closeAuction() internal {
        auctionClosed = true;

        uint256 unsold = remainingTokens;
        remainingTokens = 0;

        // Transfer funds raised to seller
        if (address(this).balance > 0) {
            (bool success,) = payable(seller).call{value: address(this).balance}("");
            require(success, "Funds transfer to seller failed");
        }

        // Return unsold tokens to seller
        if (unsold > 0) {
            bool returnSuccess = IERC20(tokenOffered).transfer(seller, unsold);
            require(returnSuccess, "Unsold token transfer failed");
        }

        emit AuctionClosed(totalFundsRaised, totalTokensSold, unsold);
    }

    receive() external payable {
        revert("Use buyTokens() to participate");
    }
}
