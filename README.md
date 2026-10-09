# SonicFair: Dual-Engine Auction SDK on Sonic

[![Network](https://img.shields.io/badge/Network-Sonic_Testnet_(14601)-blue.svg)](https://testnet.soniclabs.com)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-e6e6e6.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-14%2F14_Passed-brightgreen.svg)](https://getfoundry.sh/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**SonicFair** is an open-source Developer SDK and high-performance Dual-Engine Auction Infrastructure engineered specifically for **Sonic’s** ~400ms block finality and native **Fee Monetization (FeeM)** mechanism.

Targeted for the **Sonic Labs Innovator Fund**.

---

## 🌐 Live On-Chain Deployments (Sonic Testnet - Chain ID 14601)

| Contract / Asset | Deployed Address | Explorer / Status |
| :--- | :--- | :--- |
| **Mode 1: Batch Uniform Clearing Auction** | `0x8b962894916a9bB298A766325319dEe4c2cc5AB0` | [View on SonicScan](https://testnet.sonicscan.org/address/0x8b962894916a9bB298A766325319dEe4c2cc5AB0) |
| **Mode 2: Decaying Dutch Auction** | `0xdf5B8E3AEB35c262ebd81216b985ede9a2c771c0` | [View on SonicScan](https://testnet.sonicscan.org/address/0xdf5B8E3AEB35c262ebd81216b985ede9a2c771c0) |
| **Sample Launch Token (SLT)** | `0x261eCcb3579061dee8458811edb44f39bf1e07A2` | [View on SonicScan](https://testnet.sonicscan.org/address/0x261eCcb3579061dee8458811edb44f39bf1e07A2) |
| **Sonic FeeM Registrar Hook** | `0xDC2B0D2Dd2b7759D97D50db4eabDC36973110830` | Fee Monetization (90% of gas fees routed to developer treasury) |

### Verifiable On-Chain Interaction Proofs
* **Mode 1 Live Bidding Proof:** Block `#19074456` ([Tx Hash `0x6aa2eb...`](https://testnet.sonicscan.org/tx/0x6aa2ebc623abd6624adb77e70cf09fcc60f70be6c32cfedb74cbca765d3d24ee))
* **Mode 2 Real-Time Decayed Buy Proof:** Block `#19074369` ([Tx Hash `0x2e13db...`](https://testnet.sonicscan.org/tx/0x2e13dbb0720334a82e983f755092600525369b9a14d9f9f14ed29aa8c1ba25d7))

---

## 💡 Why SonicFair? The Problem We Solve

Token and NFT launches across standard EVM chains suffer from severe market failures:
1. **Predatory MEV Snipers & Sandwich Bots:** Traditional bonding curves (e.g., Pump.fun forks) and AMM liquidity additions are heavily sniped by bots that dump on retail participants within the first few seconds.
2. **Negative-Sum Bidding & Retail Fear:** Bidders hesitate because participating early guarantees front-running, while participating late guarantees overpaying.
3. **Lack of High-Speed Native Standards:** Despite Sonic's sub-second finality and FeeM economic incentives, builders lack a standardized, MEV-resistant price-discovery toolkit.

**SonicFair solves this with a Dual-Engine Architecture:**

```
                  ┌────────────────────────────────────────┐
                  │          SONICFAIR DUAL-ENGINE         │
                  └───────────────────┬────────────────────┘
                                      │
            ┌─────────────────────────┴─────────────────────────┐
            ▼                                                   ▼
┌───────────────────────────────┐                   ┌───────────────────────────────┐
│     ENGINE 1: BATCH UNIFORM   │                   │    ENGINE 2: TIME-DECAYING    │
│       CLEARING PRICE          │                   │         DUTCH ENGINE          │
├───────────────────────────────┤                   ├───────────────────────────────┤
│ • DeFi Fair Launches          │                   │ • Gaming Items, NFTs & Flashes│
│ • Uniform Equilibrium Price   │                   │ • Linear Decay Every ~400ms   │
│ • 100% Lossless Full Refunds  │                   │ • Instant Execution at P(t)   │
│ • Anti-Sniping Timer Window   │                   │ • Auto-Change Refund Safety   │
│ • Per-Address Anti-Whale Cap  │                   │ • Instant Sellout Conclusion  │
└───────────────────────────────┘                   └───────────────────────────────┘
            │                                                   │
            └─────────────────────────┬─────────────────────────┘
                                      ▼
                  ┌────────────────────────────────────────┐
                  │    NATIVE SONIC FeeM REGISTRAR HOOK    │
                  │  (90% Gas Revenue to Builder Treasury) │
                  └────────────────────────────────────────┘
```

---

## ⚙️ Core Engines & Mechanisms

### Engine 1: Batch Dutch Auction (Uniform Clearing Price)
* **Discrete Accumulation:** Bidders submit native $S deposits along with their maximum willingness to pay ($P_{max}$).
* **Equilibrium Clearing Price ($P^*$):** At settlement, the contract finds the market clearing price where Cumulative Demand matches Supply.
* **Uniform Settlement:** All winning bids pay the exact same clearing price $P^*$. Placing a high bid guarantees execution priority without overpaying.
* **100% Lossless:** Non-winning participants receive a **100% full refund with zero fees and zero penalty**.
* **Anti-Sniping:** Dynamic 5-minute countdown extension triggered if late bids arrive near the deadline.
* **Anti-Whale:** Configurable `maxBidPerAddress` prevents monopolization by large capital.

### Engine 2: Continuous Time-Decaying Dutch Auction
* **Sub-Second Price Decay:** Prices decay continuously and smoothly each block (~400ms) from $P_{start}$ down to $P_{floor}$.
* **Instant Execution:** Buyers purchase tokens on-demand at the real-time spot price $P(t)$ without delay.
* **Automatic Change Refund:** If remaining inventory is lower than the buyer's deposit, the contract delivers all remaining tokens and automatically refunds the excess $S$ in the same transaction.

---

## 📂 Repository Structure

```
.
├── src/
│   ├── SonicBatchAuction.sol      # Mode 1: Batch Uniform Clearing Price Engine
│   └── SonicDecayingAuction.sol   # Mode 2: Continuous Time-Decaying Dutch Engine
├── test/
│   ├── SonicBatchAuction.t.sol    # 8 Foundry tests + 256 fuzz runs
│   ├── SonicDecayingAuction.t.sol # 6 Foundry tests + 256 fuzz runs
│   └── mocks/MockERC20.sol        # Sample ERC-20 token ($SLT)
├── scripts/
│   ├── deploy_batch_auction.py    # 1-click Sonic Testnet deployer for Mode 1
│   ├── deploy_decaying_auction.py # 1-click Sonic Testnet deployer for Mode 2
│   ├── simulate_testnet_bidding.py# Live multi-wallet autonomous bidding simulator
│   ├── simulate_auction.py        # 100-Agent Monte Carlo simulation model
│   └── verify_live_status.py      # Real-time on-chain state inspection script
├── sdk/
│   ├── src/index.ts               # Typed TypeScript SDK (@sonicplay/batch-auction-sdk)
│   └── README.md                  # SDK integration guide
├── AUDIT_REPORT.md                # Internal Security Review Report (pre-audit status)
├── SONIC_INNOVATOR_PROPOSAL.md    # Official Sonic Innovator Fund application
├── OUTREACH_EMAIL.md              # Outreach templates for Sonic BD & DevRel
└── foundry.toml                   # Foundry configuration
```

---

## 🧪 Verification & Testing

### 1. Run Automated Foundry Test Suite
```bash
forge test -vvv
```
**Results:** `14/14 tests passed (100% pass rate across 2 test suites, including 256 fuzzing iterations per engine)`.

### 2. Run 100-Agent Monte Carlo Simulation
```bash
python scripts/simulate_auction.py
```
**Results:** Multi-agent Monte Carlo simulations (modeled with 100 heterogeneous agents under varying risk tolerance, valuation distributions, and arrival intervals) demonstrate that anti-snipe countdown extensions systematically disincentivize last-second sniping bots, whale concentration is bounded by per-address caps, and non-clearing bidders experience zero capital haircuts (100% principal refunded under modeled conditions).

### 3. Check Live On-Chain State on Sonic Testnet
```bash
python scripts/verify_live_status.py
```

---

## 🔒 Security & Code Review Status

> [!IMPORTANT]
> **Internal Security Review Notice:** The current contracts have completed automated testing, property-based fuzzing (256 runs per engine), and an internal security review documented in [`AUDIT_REPORT.md`](AUDIT_REPORT.md). **These contracts are deployed on Sonic Testnet for developer evaluation and pilot integrations.** In alignment with Milestone 3 of our [Sonic Innovator Fund Proposal](SONIC_INNOVATOR_PROPOSAL.md), a formal independent third-party audit will be completed prior to mainnet production deployment.

### Internal Review Findings & Mitigations
* **SEC-01 (High - Resolved):** Fixed potential false-positive winning bid claims in batch settlement via explicit `bool won` cutoff tracking.
* **SEC-02 (Medium - Resolved):** Prevented stuck funds in decaying auctions by implementing automatic change refunds on overpayment.
* **SEC-03 (Medium - Resolved):** Eliminated reentrancy attack vectors using the Checks-Effects-Interactions (CEI) pattern and mutex guards.
* **SEC-04 (Low - Resolved):** Resilient anti-sniping window (300s) mitigates validator timestamp drift under Sonic's ~400ms consensus.
* **SEC-05 (Info - Confirmed):** Sybil resistance enforced through strict per-address deposit ceilings.

---

## ⚠️ Known Limitations & Production Architecture Roadmap

To maintain complete transparency for ecosystem developers and reviewing auditors, the following architectural considerations are identified and scheduled for refinement:

1. **Batch Settlement Gas Scaling (Winner Cutoff Iteration):**
   * *Mechanism:* Mode 1 features $O(1)$ bidding via client-side sorting and on-chain hint verification. During `settleAuction()`, the contract marks winning bidders and aggregates clearing metrics.
   * *Consideration:* For auctions with very large cutoff sets (>1,000 winning bidders), iterating across all winners in a single transaction can approach EVM block gas bounds.
   * *Production Roadmap (Milestones 2 & 3):* Introduce paginated settlement batches (`settleAuctionChunk(startIdx, count)`) or off-chain state computation verified via an on-chain Merkle root commitment to support arbitrarily large participant pools.

2. **Anti-Sniping Extension Bounds:**
   * *Mechanism:* Bids submitted within the final 5 minutes automatically extend the auction duration by 5 minutes to prevent front-running.
   * *Consideration:* In theoretical adversarial conditions, griefers could place recurring minor bids to prolong auction closure.
   * *Production Roadmap:* Enforce an immutable `maxExtensionTime` ceiling (e.g., maximum 2 hours total extension past original deadline) and require a minimum bid threshold to trigger time extensions.

---

## 🚀 TypeScript SDK Quickstart

### Installation & Build
Build the typed TypeScript client directly from the repository:

```bash
cd sdk
npm install
npm run build
```

### Usage Example

> [!WARNING]
> **Private Key Safety:** Never hardcode or commit private keys. Always use burner/developer keys for testnet interactions and ensure `.env` is included in `.gitignore`.

```typescript
import { ethers } from "ethers";
import { SonicBatchAuctionClient } from "@sonicplay/batch-auction-sdk";

// 1. Connect to Sonic Testnet (Chain ID 14601)
const provider = new ethers.JsonRpcProvider("https://rpc.testnet.soniclabs.com");
const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

// 2. Initialize Client
const client = new SonicBatchAuctionClient("0x8b962894916a9bB298A766325319dEe4c2cc5AB0", signer);

// 3. Place a Bid (50 $S at maximum valuation of 0.05 $S per token)
const tx = await client.placeBid(ethers.parseEther("50"), ethers.parseEther("0.05"));
await tx.wait();

// 4. Query Real-Time Market Clearing Price
const estimate = await client.getClearingPriceEstimate();
console.log(`Clearing Price: ${ethers.formatEther(estimate.estimatedPrice)} $S`);
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
