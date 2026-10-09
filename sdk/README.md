# @sonicplay/batch-auction-sdk

TypeScript SDK and Developer Toolkit for deploying and interacting with **Batch Dutch Auctions with Uniform Clearing Price** on **Sonic**.

---

## 🚀 Key Advantages on Sonic
* **Uniform Clearing Price:** All winning bidders pay the exact same market-clearing price.
* **100% Lossless:** Non-winning participants get an instant, full 100% refund with zero penalty/fees.
* **Anti-Sniping Engine:** Dynamic countdown extensions if bids arrive in the final window.
* **Anti-Whale Protections:** Configurable per-address deposit ceiling.
* **Sonic Native FeeM Hooks:** Automated integration with Sonic's 90% gas cashback registrar.

---

## 📦 Installation

```bash
npm install @sonicplay/batch-auction-sdk ethers
```

---

## 🛠️ Quickstart (3 Lines of Code)

```typescript
import { ethers } from "ethers";
import { SonicBatchAuctionClient, SONIC_TESTNET_CHAIN_ID } from "@sonicplay/batch-auction-sdk";

// 1. Connect to Sonic Testnet (Chain ID: 14601)
const provider = new ethers.JsonRpcProvider("https://rpc.testnet.soniclabs.com");
const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

// 2. Initialize Client
const client = new SonicBatchAuctionClient("0x8b962894916a9bB298A766325319dEe4c2cc5AB0", signer);

// 3. Place a Bid (e.g. 50 $S at max price 0.05 $S per token)
const amount = ethers.parseEther("50");
const maxPrice = ethers.parseEther("0.05");
const tx = await client.placeBid(amount, maxPrice);
await tx.wait();

console.log("Bid placed successfully on Sonic!");
```

---

## 🔍 Querying Real-Time Market Clearing Price

```typescript
const estimate = await client.getClearingPriceEstimate();

console.log(`Current Estimated Clearing Price: ${ethers.formatEther(estimate.estimatedPrice)} S`);
console.log(`Winning Bids Count: ${estimate.cutoffIndex}`);
console.log(`Tokens Sold: ${ethers.formatEther(estimate.tokensSold)} SLT`);
```

---

## 🎁 Claiming Settlement

```typescript
// Claim all tokens or 100% full refunds automatically
const claimTx = await client.claimAll();
await claimTx.wait();
console.log("Tokens / refunds claimed!");
```
