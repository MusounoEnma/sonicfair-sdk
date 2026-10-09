// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SonicDecayingAuction.sol";
import "./mocks/MockERC20.sol";

contract SonicDecayingAuctionTest is Test {
    SonicDecayingAuction public auction;
    MockERC20 public token;

    address public seller = address(0xAA1);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    uint256 public constant TOTAL_TOKENS = 1_000 * 1e18; // 1,000 tokens
    uint256 public constant START_PRICE = 1.0 ether;     // 1.0 S at t=0
    uint256 public constant FLOOR_PRICE = 0.1 ether;     // 0.1 S at t=end
    uint256 public constant DURATION = 1 days;
    uint256 public constant FEEM_PROJECT_ID = 8888;

    function setUp() public {
        vm.deal(seller, 10 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        token = new MockERC20();
        token.mint(seller, TOTAL_TOKENS);

        vm.startPrank(seller);
        auction = new SonicDecayingAuction(
            address(token),
            TOTAL_TOKENS,
            START_PRICE,
            FLOOR_PRICE,
            DURATION,
            FEEM_PROJECT_ID
        );

        token.approve(address(auction), TOTAL_TOKENS);
        auction.depositOfferedTokens();
        vm.stopPrank();
    }

    function test_InitialState() public view {
        assertEq(auction.seller(), seller);
        assertEq(auction.totalTokensOffered(), TOTAL_TOKENS);
        assertEq(auction.remainingTokens(), TOTAL_TOKENS);
        assertEq(auction.getCurrentPrice(), START_PRICE);
        assertEq(auction.tokensDeposited(), true);
    }

    function test_PriceDecayOverTime() public {
        // At start: price = 1.0 S
        assertEq(auction.getCurrentPrice(), 1.0 ether);

        // At halfway (12 hours): price = 1.0 - (0.9 * 0.5) = 0.55 S
        vm.warp(auction.startTime() + (DURATION / 2));
        assertEq(auction.getCurrentPrice(), 0.55 ether);

        // At 75% duration (18 hours): price = 1.0 - (0.9 * 0.75) = 0.325 S
        vm.warp(auction.startTime() + (DURATION * 3 / 4));
        assertEq(auction.getCurrentPrice(), 0.325 ether);

        // At end (24 hours): price = floorPrice = 0.1 S
        vm.warp(auction.endTime());
        assertEq(auction.getCurrentPrice(), FLOOR_PRICE);
    }

    function test_InstantPurchaseAtDecayedPrice() public {
        // Alice waits until halfway (price is 0.55 S)
        vm.warp(auction.startTime() + (DURATION / 2));
        uint256 curPrice = auction.getCurrentPrice();
        assertEq(curPrice, 0.55 ether);

        // Alice buys with 5.5 S -> gets exactly 10 tokens
        vm.prank(alice);
        auction.buyTokens{value: 5.5 ether}();

        assertEq(token.balanceOf(alice), 10 * 1e18);
        assertEq(auction.totalTokensSold(), 10 * 1e18);
        assertEq(auction.remainingTokens(), (TOTAL_TOKENS - 10 * 1e18));
    }

    function test_AutomaticChangeRefundWhenOverpaying() public {
        // Warp to end when price is 0.1 S
        vm.warp(auction.endTime());

        // Alice sends 200 S, but total remaining inventory is 1,000 tokens * 0.1 S = 100 S
        vm.deal(alice, 300 ether);
        uint256 aliceBalBefore = alice.balance;
        vm.prank(alice);
        auction.buyTokens{value: 200 ether}();

        // Alice bought all 1,000 tokens for 100 S, and received 100 S change refunded!
        assertEq(token.balanceOf(alice), TOTAL_TOKENS);
        assertEq(aliceBalBefore - alice.balance, 100 ether); // Net spent exactly 100 S
        assertEq(auction.remainingTokens(), 0);
        assertTrue(auction.auctionClosed());
    }

    function test_SellerReceivesProceedsAndUnsoldTokens() public {
        // Warp to halfway (price 0.55 S)
        vm.warp(auction.startTime() + (DURATION / 2));

        // Alice buys 10 tokens (5.5 S)
        vm.prank(alice);
        auction.buyTokens{value: 5.5 ether}();

        // Warp to past end
        vm.warp(auction.endTime() + 1);

        uint256 sellerBalBefore = seller.balance;
        uint256 sellerTokensBefore = token.balanceOf(seller);

        auction.closeAuction();

        assertTrue(auction.auctionClosed());
        // Seller gets 5.5 S proceeds
        assertEq(seller.balance - sellerBalBefore, 5.5 ether);
        // Seller gets remaining 990 tokens back
        assertEq(token.balanceOf(seller) - sellerTokensBefore, 990 * 1e18);
    }

    function test_FuzzDecayedPurchase(uint32 warpSeconds, uint96 buyAmount) public {
        uint256 safeWarp = bound(uint256(warpSeconds), 0, DURATION);
        uint256 safeAmount = bound(uint256(buyAmount), 0.01 ether, 50 ether);

        vm.warp(auction.startTime() + safeWarp);
        uint256 curPrice = auction.getCurrentPrice();
        assertTrue(curPrice >= FLOOR_PRICE && curPrice <= START_PRICE);

        vm.deal(bob, safeAmount);
        vm.prank(bob);
        auction.buyTokens{value: safeAmount}();

        assertTrue(token.balanceOf(bob) > 0);
    }
}
