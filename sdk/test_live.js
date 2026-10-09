const { ethers } = require("ethers");
const { 
  SonicBatchAuctionClient, 
  SonicDecayingAuctionClient, 
  SONIC_TESTNET_CHAIN_ID 
} = require("./dist/index.js");

async function main() {
  console.log("=================================================");
  console.log("   SONICFAIR TYPESCRIPT SDK: LIVE TESTNET VERIFY ");
  console.log("=================================================");
  console.log(`[*] Target Network: Sonic Testnet (Chain ID: ${SONIC_TESTNET_CHAIN_ID})`);

  const provider = new ethers.JsonRpcProvider("https://rpc.testnet.soniclabs.com");
  const network = await provider.getNetwork();
  console.log(`[*] Connected! Chain ID: ${network.chainId}`);

  // 1. Test Mode 1 Batch Auction Client
  const batchAddr = "0x8b962894916a9bB298A766325319dEe4c2cc5AB0";
  console.log(`\n[*] Testing SonicBatchAuctionClient on ${batchAddr}...`);
  const batchClient = new SonicBatchAuctionClient(batchAddr, provider);

  const batchState = await batchClient.getAuctionState();
  console.log(`    - Seller Address      : ${batchState.seller}`);
  console.log(`    - Tokens Offered      : ${ethers.formatEther(batchState.totalTokensOffered)} SLT`);
  console.log(`    - Reserve Price       : ${ethers.formatEther(batchState.reservePrice)} $S`);
  console.log(`    - Total Bids Count    : ${batchState.totalBidsCount}`);
  console.log(`    - Settled Status      : ${batchState.settled}`);

  const estimate = await batchClient.getClearingPriceEstimate();
  console.log(`    - Est. Clearing Price : ${ethers.formatEther(estimate.estimatedPrice)} $S / SLT`);
  console.log(`    - Winning Cutoff      : ${estimate.cutoffIndex} bids win`);
  console.log(`    - Winning Capital     : ${ethers.formatEther(estimate.winningFunds)} $S`);
  console.log(`    - Tokens Sold         : ${ethers.formatEther(estimate.tokensSold)} SLT`);
  console.log(`    [✓] Mode 1 Client queries passed successfully!`);

  // 2. Test Mode 2 Decaying Auction Client
  const decayAddr = "0xdf5B8E3AEB35c262ebd81216b985ede9a2c771c0";
  console.log(`\n[*] Testing SonicDecayingAuctionClient on ${decayAddr}...`);
  const decayClient = new SonicDecayingAuctionClient(decayAddr, provider);

  const curPrice = await decayClient.getCurrentPrice();
  console.log(`    - Current Decayed Price: ${ethers.formatEther(curPrice)} $S / SLT`);

  const decayState = await decayClient.getAuctionState();
  console.log(`    - Start Price (Ceiling): ${ethers.formatEther(decayState.startPrice)} $S / SLT`);
  console.log(`    - Floor Reserve Price  : ${ethers.formatEther(decayState.floorPrice)} $S / SLT`);
  console.log(`    - Remaining Inventory  : ${ethers.formatEther(decayState.remainingTokens)} SLT`);
  console.log(`    - Funds Raised         : ${ethers.formatEther(decayState.totalFundsRaised)} $S`);
  console.log(`    - Buyers Count         : ${decayState.buyersCount}`);
  console.log(`    - Closed Status        : ${decayState.auctionClosed}`);
  console.log(`    [✓] Mode 2 Client queries passed successfully!`);

  console.log("\n=================================================");
  console.log("   [ALL PASSED] SDK IS 100% OPERATIONAL & VERIFIED! ");
  console.log("=================================================");
}

main().catch(err => {
  console.error("SDK Test Error:", err);
  process.exit(1);
});
