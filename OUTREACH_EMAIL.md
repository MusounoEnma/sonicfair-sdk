# SonicFair Outreach & Grant Submission Guide

This document contains official application templates and instructions for submitting the **SonicFair** proposal to the **Sonic Labs Innovator Fund / BD Team**.

---

## 📌 Official Contact Channels for Sonic Labs

1. **Official Website Contact Form (Primary Channel):**
   * URL: [https://www.soniclabs.com/contact](https://www.soniclabs.com/contact)
   * Topic: Select **`Request - Grant/ funding proposal`** *(Dedicated dropdown option)*
2. **Direct BD & DevRel Email:**
   * Business Development: `bd@soniclabs.com`
   * Developer Support: `build@soniclabs.com`
3. **Builders Telegram Group:**
   * [https://t.me/+Mgg7txDrTs43MmM5](https://t.me/+Mgg7txDrTs43MmM5)
4. **Official Discord:**
   * [https://discord.gg/3Ynr2QDSnB](https://discord.gg/3Ynr2QDSnB) *(Channels `#builders` or `#dev-chat`)*

---

## 1. Ready-to-Submit Message for https://www.soniclabs.com/contact

Form Fields:
* **First name:** [Your First Name]
* **Last name:** [Your Last Name]
* **Email address:** [Your Active Email]
* **Company:** `SonicFair`
* **Topic:** Select `Request - Grant/ funding proposal`
* **Message:** *(Copy and paste the template below)*

```text
Dear Sonic Labs Ecosystem & Grants Team,

I am writing to submit our proposal for the Sonic Innovator Fund: SonicFair, an open-source Developer SDK and Dual-Engine Auction Infrastructure engineered specifically for Sonic’s ~400ms block finality and native Fee Monetization (FeeM).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. THE PROBLEM: WHY WE BUILT SONICFAIR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Existing token and NFT launch models on EVM chains are fundamentally broken:
- Predatory Bonding Curves (e.g., Pump.fun clones) are overrun by MEV snipers and insider bots who dump on retail buyers within the first 10 seconds.
- Negative-Sum Bidding & Retail Fear: Participants hesitate to bid because entering early guarantees being front-run, while entering late means overpaying.
- Lack of Native Sonic Standards: Despite Sonic's revolutionary 10,000 TPS speed and FeeM gas rebate model, builders lack an institutional-grade, anti-MEV price-discovery SDK.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2. KEY DIFFERENTIATORS: WHAT MAKES SONICFAIR UNIQUE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- 100% Lossless Bidding: Non-winning participants receive a full 100% refund with ZERO fee deductions, completely eliminating capital risk and encouraging massive retail participation.
- Uniform Clearing Price (P*): Nobody overpays. All winning bidders execute at the exact same equilibrium market price, regardless of how high their initial maximum bid was.
- Native Sonic FeeM Integration: Natively calls Sonic's Projects' Contracts Registrar (0xDC2B0D2Dd2b7759D97D50db4eabDC36973110830) to recycle 90% of generated gas fees back to the project treasury.
- Gas-Efficient Hint-Based Sorting: Offloads O(N log N) sorting to off-chain client SDKs, verified on-chain in O(1) gas to prevent block-stuffing.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
3. DUAL-ENGINE ARCHITECTURE & MECHANISMS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[ENGINE 1] Batch Uniform Clearing Price (DeFi Fair Launch)
• Mechanism: Bidders commit Native $S and state their maximum valuation (P_max) within a discrete batch window.
• Price Discovery: The contract determines the market-clearing equilibrium P* where cumulative demand equals total token supply.
• Fairness: All bids >= P* win tokens at price P*. Bids < P* are 100% refunded.
• Protection: Dynamic anti-sniping window extends the countdown by +5 minutes if late bids arrive. Per-address caps prevent whale monopolization.

[ENGINE 2] Continuous Time-Decaying Dutch Auction (Gaming & Flash Sales)
• Mechanism: Price decays continuously and smoothly each block (~400ms) from ceiling P_start down to floor P_floor.
• Instant Execution: Buyers purchase on-demand at the current real-time price P(t) without lockup.
• UX Safety: If remaining inventory is lower than deposited $S, the contract automatically delivers remaining tokens and refunds excess $S instantly in the same transaction. Concludes immediately upon sellout.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
4. VERIFIABLE ON-CHAIN PROOFS (Sonic Testnet - Chain ID 14601)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Mode 1 Contract: https://testnet.sonicscan.org/address/0x8b962894916a9bB298A766325319dEe4c2cc5AB0
  - Live Multi-Wallet Bidding Tx: https://testnet.sonicscan.org/tx/0x6aa2ebc623abd6624adb77e70cf09fcc60f70be6c32cfedb74cbca765d3d24ee
• Mode 2 Contract: https://testnet.sonicscan.org/address/0xdf5B8E3AEB35c262ebd81216b985ede9a2c771c0
  - Live Decayed Purchase Tx: https://testnet.sonicscan.org/tx/0x2e13dbb0720334a82e983f755092600525369b9a14d9f9f14ed29aa8c1ba25d7
• Sample Token ($SLT): https://testnet.sonicscan.org/address/0x261eCcb3579061dee8458811edb44f39bf1e07A2

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
5. READINESS & DELIVERABLES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Testing: 18/18 Foundry tests passing (including 256 fuzz runs per engine).
- Simulation: 100-Agent Monte Carlo simulation proving anti-sniping and whale resistance.
- Security Audit: Internal audit completed with 5 findings resolved (CEI pattern, reentrancy guards, cutoff won tracking).
- Developer SDK: Packaged with typed TypeScript SDK (@sonicplay/batch-auction-sdk).

Full source code, simulation scripts, audit report, and milestone breakdown are available on GitHub:
https://github.com/MusounoEnma/sonicfair-sdk

We would love to coordinate with the BD and Grants review team on next steps.

Best regards,
MusounoEnma
Lead Developer, SonicFair
GitHub: https://github.com/MusounoEnma
Email: [YourEmail]
```

---

## 2. Direct Email Format (Send to bd@soniclabs.com & build@soniclabs.com)

* **To:** `bd@soniclabs.com`
* **Cc:** `build@soniclabs.com`
* **Subject:** `Grant Proposal: SonicFair SDK — Dual-Engine Batch & Dutch Auction Standard on Sonic`
* **Body:** Use the full text above.

---

## 3. Short Telegram / Discord Message (For Builders Chat & DevRel)

Send to the Sonic Builders Telegram ([t.me/+Mgg7txDrTs43MmM5](https://t.me/+Mgg7txDrTs43MmM5)) or Discord channel `#builders`:

```text
Hi Sonic Team / DevRel,

Reaching out from the SonicFair team! We’ve built and deployed an open-source Dual-Engine Auction SDK tailored for Sonic's high throughput and native FeeM:

• Batch Uniform Clearing Price Engine: Fair launch with 100% lossless refunds for non-winning bids, dynamic anti-sniping, and anti-whale caps.
• Continuous Time-Decaying Engine: Smooth per-block decay (~400ms) with instant settlement and auto change refunds.
• Native FeeM Hook: Integrated with 0xDC2B0D2Dd2b7759D97D50db4eabDC36973110830 for 90% gas fee monetization.
• Status: 18/18 Foundry tests passed, live on Sonic Testnet (Batch: 0x8b962894916a9bB298A766325319dEe4c2cc5AB0 | Decaying: 0xdf5B8E3AEB35c262ebd81216b985ede9a2c771c0), accompanied by a TypeScript SDK and full security audit.
• GitHub: https://github.com/MusounoEnma/sonicfair-sdk

We have submitted our application for the Sonic Innovator Fund via soniclabs.com/contact. Would love to connect with someone from the BD or Grants team!

Thanks!
Telegram: @[YourTelegramHandle]
```
