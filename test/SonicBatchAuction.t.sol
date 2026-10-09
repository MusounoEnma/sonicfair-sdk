// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SonicBatchAuction.sol";
import "./mocks/MockERC20.sol";

contract SonicBatchAuctionTest is Test {
    SonicBatchAuction public auction;
    MockERC20 public token;

    address public seller = address(0xAA1);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public charlie = address(0xCC);
    address public dave = address(0xDD);

    uint256 public constant TOTAL_TOKENS = 10_000 * 1e18; // 10,000 tokens
    uint256 public constant RESERVE_PRICE = 0.01 ether;   // 0.01 S per token
    uint256 public constant DURATION = 1 days;
    uint256 public constant MAX_BID_PER_ADDR = 500 ether;
    uint256 public constant ANTI_SNIPE_WINDOW = 300;     // 5 minutes
    uint256 public constant ANTI_SNIPE_EXT = 300;        // 5 minutes
    uint256 public constant FEEM_PROJECT_ID = 9999;

    function setUp() public {
        vm.deal(seller, 100 ether);
        vm.deal(alice, 1000 ether);
        vm.deal(bob, 1000 ether);
        vm.deal(charlie, 1000 ether);
        vm.deal(dave, 1000 ether);

        // Deploy Mock Token
        token = new MockERC20();
        token.mint(seller, TOTAL_TOKENS);

        // Deploy auction contract
        vm.startPrank(seller);
        auction = new SonicBatchAuction(
            address(token),
            TOTAL_TOKENS,
            RESERVE_PRICE,
            DURATION,
            MAX_BID_PER_ADDR,
            ANTI_SNIPE_WINDOW,
            ANTI_SNIPE_EXT,
            FEEM_PROJECT_ID
        );

        // Seller funds the auction with tokens
        token.approve(address(auction), TOTAL_TOKENS);
        auction.depositOfferedTokens();
        vm.stopPrank();
    }

    function test_InitialAuctionState() public view {
        assertEq(auction.seller(), seller);
        assertEq(auction.tokenOffered(), address(token));
        assertEq(auction.totalTokensOffered(), TOTAL_TOKENS);
        assertEq(auction.reservePrice(), RESERVE_PRICE);
        assertEq(auction.tokensDeposited(), true);
        assertEq(token.balanceOf(address(auction)), TOTAL_TOKENS);
    }

    function test_BiddingAndSorting() public {
        // Alice bids at 0.05 S
        vm.prank(alice);
        auction.placeBid{value: 100 ether}(0.05 ether, 0);

        // Bob bids at 0.10 S (higher than Alice)
        vm.prank(bob);
        auction.placeBid{value: 100 ether}(0.10 ether, 0);

        // Charlie bids at 0.02 S (lower than Alice)
        vm.prank(charlie);
        auction.placeBid{value: 50 ether}(0.02 ether, 2);

        // Verify order in sortedBidIds (descending by price)
        // Bob (0.10 S) -> Alice (0.05 S) -> Charlie (0.02 S)
        assertEq(auction.sortedBidIds(0), 1); // Bob's bidId is 1
        assertEq(auction.sortedBidIds(1), 0); // Alice's bidId is 0
        assertEq(auction.sortedBidIds(2), 2); // Charlie's bidId is 2
    }

    function test_EnforceMaxBidPerAddress() public {
        vm.startPrank(alice);
        auction.placeBid{value: 300 ether}(0.05 ether, 0);

        // Exceeds 500 ether cap
        vm.expectRevert("Exceeds max bid per address");
        auction.placeBid{value: 201 ether}(0.05 ether, 0);
        vm.stopPrank();
    }

    function test_AntiSnipingExtension() public {
        uint256 originalEnd = auction.auctionEndTime();

        // Warp time to 60 seconds before auction end (inside 300s window)
        vm.warp(originalEnd - 60);

        vm.prank(alice);
        auction.placeBid{value: 10 ether}(0.05 ether, 0);

        uint256 newEnd = auction.auctionEndTime();
        // Should be extended by ANTI_SNIPE_EXT (300 seconds) from warp time
        assertEq(newEnd, (originalEnd - 60) + ANTI_SNIPE_EXT);
        assertTrue(newEnd > originalEnd);
    }

    function test_UniformClearingPriceAndSettlement() public {
        // Setup demand to clear 10,000 tokens:
        // Bob bids 100 S at maxPrice 0.05 S
        // Alice bids 100 S at maxPrice 0.04 S
        // Total funds = 200 S.
        // Implied uniform clearing price = 200 S / 10,000 tokens = 0.02 S per token!
        // Both Bob (max 0.05) and Alice (max 0.04) are >= 0.02 S!
        // Charlie bids 50 S at 0.015 S (below 0.02 S -> Losing bid!)

        vm.prank(bob);
        auction.placeBid{value: 100 ether}(0.05 ether, 0);

        vm.prank(alice);
        auction.placeBid{value: 100 ether}(0.04 ether, 0);

        vm.prank(charlie);
        auction.placeBid{value: 50 ether}(0.015 ether, 2);

        // Check estimated clearing price before settlement
        (
            uint256 estPrice,
            uint256 cutoff,
            uint256 winningFunds,
            uint256 tokensSold
        ) = auction.calculateClearingPrice();

        assertEq(estPrice, 0.02 ether); // 200 ether / 10,000 tokens = 0.02 ether
        assertEq(cutoff, 2); // Bob and Alice win
        assertEq(winningFunds, 200 ether);
        assertEq(tokensSold, TOTAL_TOKENS);

        // Warp to after auction end
        vm.warp(auction.auctionEndTime() + 1);

        uint256 sellerBalBefore = seller.balance;
        auction.settleAuction();

        assertTrue(auction.settled());
        assertEq(auction.clearingPrice(), 0.02 ether);
        assertEq(seller.balance - sellerBalBefore, 200 ether);

        // Bob claims: should get 100 S / 0.02 S = 5,000 tokens
        uint256 bobBidId = 0;
        vm.prank(bob);
        auction.claim(bobBidId);
        assertEq(token.balanceOf(bob), 5_000 * 1e18);

        // Alice claims: should get 100 S / 0.02 S = 5,000 tokens
        uint256 aliceBidId = 1;
        vm.prank(alice);
        auction.claim(aliceBidId);
        assertEq(token.balanceOf(alice), 5_000 * 1e18);

        // Charlie (losing bid) claims: receives 100% full refund (50 S) with 0 fees!
        uint256 charlieBalBefore = charlie.balance;
        uint256 charlieBidId = 2;
        vm.prank(charlie);
        auction.claim(charlieBidId);
        assertEq(charlie.balance - charlieBalBefore, 50 ether);
        assertEq(token.balanceOf(charlie), 0);
    }

    function test_UndersubscribedAuctionReturnsUnsoldTokens() public {
        // Only Alice bids 50 S at 0.02 S. Reserve price is 0.01 S.
        // Total tokens offered = 10,000.
        // 50 S / 10,000 tokens = 0.005 S (below reserve 0.01 S).
        // Therefore, clearing price must be Reserve Price (0.01 S).
        // Alice buys 50 S / 0.01 S = 5,000 tokens.
        // Remaining 5,000 tokens must be returned to seller!

        vm.prank(alice);
        auction.placeBid{value: 50 ether}(0.02 ether, 0);

        vm.warp(auction.auctionEndTime() + 1);

        uint256 sellerTokensBefore = token.balanceOf(seller);
        auction.settleAuction();

        assertEq(auction.clearingPrice(), RESERVE_PRICE);
        assertEq(token.balanceOf(seller) - sellerTokensBefore, 5_000 * 1e18); // Unsold returned!

        // Alice claims her 5,000 tokens
        vm.prank(alice);
        auction.claim(0);
        assertEq(token.balanceOf(alice), 5_000 * 1e18);
    }

    function test_ClaimAllConvenience() public {
        vm.startPrank(alice);
        auction.placeBid{value: 20 ether}(0.05 ether, 0);
        auction.placeBid{value: 30 ether}(0.05 ether, 0);
        vm.stopPrank();

        vm.warp(auction.auctionEndTime() + 1);
        auction.settleAuction();

        vm.prank(alice);
        auction.claimAll();

        assertTrue(token.balanceOf(alice) > 0);
    }

    function test_FuzzDiverseBids(uint96 bidAmountRaw, uint96 maxPriceRaw) public {
        uint256 bidAmount = bound(uint256(bidAmountRaw), 0.1 ether, 100 ether);
        uint256 maxPrice = bound(uint256(maxPriceRaw), RESERVE_PRICE, 1 ether);

        vm.deal(dave, bidAmount);
        vm.prank(dave);
        auction.placeBid{value: bidAmount}(maxPrice, 0);

        (uint256 estPrice, , , ) = auction.calculateClearingPrice();
        assertTrue(estPrice >= RESERVE_PRICE);

        vm.warp(auction.auctionEndTime() + 1);
        auction.settleAuction();

        vm.prank(dave);
        auction.claim(0);

        // Dave either has tokens or got full refund, never loses funds unexpectedly
        assertTrue(token.balanceOf(dave) > 0 || dave.balance == bidAmount);
    }
}
