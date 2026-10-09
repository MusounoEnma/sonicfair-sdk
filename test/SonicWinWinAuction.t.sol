// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SonicWinWinAuction.sol";

contract SonicWinWinAuctionTest is Test {
    SonicWinWinAuction public auction;
    address public dev = address(0xAA1);
    address public alice = address(0x111);
    address public bob = address(0x222);
    address public charlie = address(0x333);

    function setUp() public {
        vm.deal(dev, 100 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);

        vm.prank(dev);
        auction = new SonicWinWinAuction{value: 1 ether}(12345); // Seed Round 1 with 1 S
    }

    function test_InitialRoundState() public view {
        (
            uint256 roundId,
            uint256 remaining,
            address topBidder,
            uint256 topBid,
            uint256 prizePot,
            uint256 minNextBid,
            uint256 bidCount
        ) = auction.getCurrentRoundInfo();

        assertEq(roundId, 1);
        assertGt(remaining, 0);
        assertEq(topBidder, address(0));
        assertEq(topBid, 0);
        assertEq(prizePot, 1 ether);
        assertEq(minNextBid, 0.1 ether);
        assertEq(bidCount, 0);
    }

    function test_BiddingAndOutbidProfitBonus() public {
        // Alice bids 1 S
        uint256 devBalanceBefore = dev.balance;
        vm.prank(alice);
        auction.placeBid{value: 1 ether}();

        // Check dev fee (2% of 1 ether = 0.02 ether)
        assertEq(dev.balance - devBalanceBefore, 0.02 ether);

        // Bob outbids Alice with 2 S (+100% > 10% min increment)
        uint256 aliceBalanceBefore = alice.balance;
        vm.prank(bob);
        auction.placeBid{value: 2 ether}();

        // Alice must receive: her original bid (1 ether) + 5% reward bonus of Bob's bid (0.1 ether) = 1.1 ether!
        // That means Alice made 0.1 ether PURE PROFIT just by being outbid!
        assertEq(alice.balance - aliceBalanceBefore, 1.1 ether);

        // Charlie outbids Bob with 3 S
        uint256 bobBalanceBefore = bob.balance;
        vm.prank(charlie);
        auction.placeBid{value: 3 ether}();

        // Bob must receive: 2 ether + (5% of 3 ether = 0.15 ether) = 2.15 ether!
        assertEq(bob.balance - bobBalanceBefore, 2.15 ether);
    }

    function test_LateBidAntiSnipeExtension() public {
        vm.prank(alice);
        auction.placeBid{value: 1 ether}();

        (, uint256 timeRemaining,,,,,) = auction.getCurrentRoundInfo();

        // Fast-forward to 10 seconds before round end
        vm.warp(block.timestamp + timeRemaining - 10);

        // Bob bids
        vm.prank(bob);
        auction.placeBid{value: 2 ether}();

        // Timer should have extended back to at least 30 seconds
        (, uint256 newRemaining,,,,,) = auction.getCurrentRoundInfo();
        assertGe(newRemaining, 29);
    }

    function test_WinnerSettlementAndRoundRoll() public {
        vm.prank(alice);
        auction.placeBid{value: 1 ether}();

        vm.prank(bob);
        auction.placeBid{value: 2 ether}();

        // Fast forward past round end
        vm.warp(block.timestamp + 4 minutes);

        uint256 bobBalanceBefore = bob.balance;
        uint256 potBeforeSettle = address(auction).balance;

        // Settle round
        auction.settleAndNextRound();

        // Bob (highest bidder) wins the remaining prize pot!
        assertEq(bob.balance - bobBalanceBefore, potBeforeSettle);

        // Round should now be 2
        (uint256 newRoundId,,,,,,) = auction.getCurrentRoundInfo();
        assertEq(newRoundId, 2);
    }
}
