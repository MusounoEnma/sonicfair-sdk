# Sonic Innovator Fund Application: SonicFair SDK (Batch Dutch Auction Engine)

## 1. Project Overview
* **Project Name:** SonicFair SDK
* **Vertical / Category:** Developer Tooling / DeFi Infrastructure / Gaming Standard
* **Tagline:** Dual-Engine Auction SDK on Sonic: Batch Uniform Clearing Price (DeFi Fair Launch) & Continuous Time-Decaying Dutch Auction (Gaming & Flash Sales) with Native FeeM Integration.
* **Target Network:** Sonic Testnet (Chain ID 14601) & Sonic Mainnet (Chain ID 146).
* **Live Testnet Contract (Mode 1 - Batch Uniform):** `0x8b962894916a9bB298A766325319dEe4c2cc5AB0`
  - Explorer: `https://testnet.sonicscan.org/address/0x8b962894916a9bB298A766325319dEe4c2cc5AB0`
* **Live Testnet Contract (Mode 2 - Time-Decay Dutch):** `0xdf5B8E3AEB35c262ebd81216b985ede9a2c771c0`
  - Explorer: `https://testnet.sonicscan.org/address/0xdf5B8E3AEB35c262ebd81216b985ede9a2c771c0`
* **Sample Auction Token (SLT):** [`0x261eCcb3579061dee8458811edb44f39bf1e07A2`](https://testnet.sonicscan.org/address/0x261eCcb3579061dee8458811edb44f39bf1e07A2)
* **GitHub Repository:** [`https://github.com/MusounoEnma/sonicfair-sdk`](https://github.com/MusounoEnma/sonicfair-sdk)

---

## 2. Problem & Value Proposition to Sonic
Token, Gaming, and NFT sales across modern EVM ecosystems suffer from severe structural failures:
1. **Predatory MEV & Sandwich Bots:** In standard AMM pools or English auctions, bots manipulate liquidity and frontrun ordinary participants.
2. **First-Come, First-Served Gas Wars:** High-demand mints trigger network congestion and unfair access, favoring high-latency bot operators.
3. **Winner's Curse & Negative-Sum Psychology:** In traditional auctions, participants fear overpaying or losing their capital.

### How SonicFair Solves This with Dual-Engine Flexibility:
* **Engine 1: Batch Dutch Auction with Uniform Clearing Price (`SonicBatchAuction.sol`):**
  - **Equilibrium Market Price:** Finds the exact clearing price ($P^*$) where supply meets demand. All winning bidders execute at the same fair price, regardless of their bid ceiling.
  - **100% Lossless for Non-Winners:** Losing bidders receive an instant full 100% refund with zero fees/penalties.
  - **Anti-Sniping & Anti-Whale:** Dynamic countdown extensions and per-address deposit limits.

* **Engine 2: Continuous Time-Decaying Dutch Auction (`SonicDecayingAuction.sol`):**
  - **Sub-Second Continuous Price Decay:** Price automatically drops every second (~400ms blocks on Sonic) from ceiling to floor price.
  - **Adrenaline & FOMO:** Perfect for gaming item drops, NFT mints, and flash sales. Buyers decide whether to buy now or wait for a lower price before inventory sells out.
  - **Instant Execution & Auto-Change Refund:** Excess funds are refunded immediately when inventory is exhausted.

* **Shared Native Sonic Superpower (FeeM):**
  - Both engines natively connect to Sonic's Fee Monetization registrar (`0xDC2B0D2Dd2b7759D97D50db4eabDC36973110830`), routing 90% of network gas fees back to game creators or user loyalty rebates.

---

## 3. Technical Architecture & Verification

```
[Bidders (Retail, Whales, Bots)] 
              │
              ▼ (placeBid: Native $S + maxPrice)
     [SonicBatchAuction Contract] ──► [Sonic FeeM Registrar] (90% Gas Rebates)
              │
    ┌─────────┴────────────────────────┐
    ▼ (Settlement: block.timestamp >= endTime)
[Uniform Clearing Price P* Computed]
    ├─► Winning Bidders: Receive Tokens at P* (Pro-rata allocation)
    ├─► Losing Bidders: 100% Full Capital Refund (Zero fee deduction)
    └─► Seller: Receives Raised $S + Any Unsold Tokens returned safely
```

### Verification & Test Suite Status:
1. **Foundry Test Suite (`test/SonicBatchAuction.t.sol`):**
   * **100% Pass Rate** across 8 core test suites including:
     - `test_AntiSnipingExtension`
     - `test_BiddingAndSorting`
     - `test_ClaimAllConvenience`
     - `test_EnforceMaxBidPerAddress`
     - `test_UniformClearingPriceAndSettlement`
     - `test_UndersubscribedAuctionReturnsUnsoldTokens`
     - `test_FuzzDiverseBids` (**256 fuzz runs passed**).
2. **Monte Carlo Agent-Based Simulation (`scripts/simulate_auction.py`):**
   * Simulated 100 heterogeneous agents (60 Retail, 25 Momentum, 5 Whales, 10 Sniping Bots).
   * Verified that sniping bots were neutralized via dynamic extensions and whale concentration was constrained by the per-address cap.
3. **TypeScript SDK (`@sonicplay/batch-auction-sdk`):**
   * Plug-and-play TypeScript client allowing any Sonic game or dApp to integrate a batch auction in under 5 minutes.

---

## 4. Grant Request & Milestone-Based Roadmap

We structure our proposal into clear, measurable deliverables:

### Milestone 1 (Completed & Open-Source):
* Core Solidity smart contract (`SonicBatchAuction.sol`).
* 100% passing Foundry test suite with invariant fuzzing.
* Monte Carlo agent-based simulation verifying uniform price clearing and bot resilience.
* TypeScript SDK client (`sdk/src/index.ts`) with typed viem/ethers integration.

### Milestone 2 (Testnet Pilot & Ecosystem Integration) — *Target: 2 Weeks post-grant*:
* Deployment and verification on Sonic Blaze Testnet (Chain ID 57054).
* Pilot partnership / integration with 1–2 initial Sonic ecosystem projects (meme launchpad or gaming NFT drop).
* Interactive developer playground & documentation portal.
* **Requested Funding:** $10,000 in $S.

### Milestone 3 (Advanced Modules & Mainnet Security Audit) — *Target: 4 Weeks post-grant*:
* Implementation of Sealed-Bid Commit-Reveal Module.
* Gasless Bidding sponsorship via Sonic Pectra / EIP-7702.
* Comprehensive third-party smart contract security audit.
* Production deployment on Sonic Mainnet (Chain ID 146).
* **Requested Funding:** $15,000 in $S.

---

## 5. Value to the Sonic Ecosystem
1. **New Standard for Fair Launches:** Provides emerging projects on Sonic with an institutional-grade, MEV-resistant alternative to predatory bonding curves.
2. **Transaction Velocity & FeeM Yield:** Batch auctions drive high-frequency, authentic bidding activity, directly boosting network TPS and FeeM treasury accumulation.
3. **Public Good for Builders:** Any game developer, NFT artist, or DeFi protocol on Sonic can deploy an auction with a single function call.

---

## 6. Contact Information
* **Lead Developer / Team:** SonicFair Team
* **Telegram:** `@yourhandle` *(Insert handle)*
* **Twitter / X:** `@yourhandle` *(Optional)*
* **Email:** `contact@yourdomain.com` *(Insert email)*
