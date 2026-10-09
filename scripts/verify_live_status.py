import json
import os
import sys
from web3 import Web3

RPC = "https://rpc.testnet.soniclabs.com"
w3 = Web3(Web3.HTTPProvider(RPC))
print(f"[*] Connected to Sonic Testnet: {w3.is_connected()}, Block: #{w3.eth.block_number}")

# 1. Mode 1: Batch Auction (Audited deployment)
batch_addr = sys.argv[1] if len(sys.argv) > 1 else "0x8b962894916a9bB298A766325319dEe4c2cc5AB0"
with open("out/SonicBatchAuction.sol/SonicBatchAuction.json") as f:
    batch_abi = json.load(f)["abi"]
batch = w3.eth.contract(address=Web3.to_checksum_address(batch_addr), abi=batch_abi)

print("\n" + "=" * 65)
print("  MODE 1: BATCH UNIFORM CLEARING PRICE AUCTION")
print("=" * 65)
print(f"Contract Address : {batch_addr}")
print(f"Offered Supply   : {w3.from_wei(batch.functions.totalTokensOffered().call(), 'ether')} SLT")
print(f"Reserve Price    : {w3.from_wei(batch.functions.reservePrice().call(), 'ether')} $S")
print(f"Settled Status   : {batch.functions.settled().call()}")

total_bids = batch.functions.totalBidsCount().call()
print(f"Total Bids Count : {total_bids}")

for i in range(total_bids):
    b = batch.functions.bids(i).call()
    print(f"  -> Bid #{i}: Bidder={b[1]} | Deposited={w3.from_wei(b[2], 'ether')} $S | MaxPrice={w3.from_wei(b[3], 'ether')} $S | Won={b[6]}")

est_p, cutoff, win_funds, tokens_sold = batch.functions.calculateClearingPrice().call()
print(f"Clearing Price   : {w3.from_wei(est_p, 'ether')} $S / SLT")
print(f"Winning Cutoff   : {cutoff} winners")
print(f"Winning Funds    : {w3.from_wei(win_funds, 'ether')} $S")
print(f"Tokens Sold      : {w3.from_wei(tokens_sold, 'ether')} SLT")

# 2. Mode 2: Decaying Dutch Auction
decay_addr = "0xdf5B8E3AEB35c262ebd81216b985ede9a2c771c0"
with open("out/SonicDecayingAuction.sol/SonicDecayingAuction.json") as f:
    decay_abi = json.load(f)["abi"]
decay = w3.eth.contract(address=Web3.to_checksum_address(decay_addr), abi=decay_abi)

print("\n" + "=" * 65)
print("  MODE 2: CONTINUOUS TIME-DECAYING DUTCH AUCTION")
print("=" * 65)
print(f"Contract Address : {decay_addr}")
print(f"Start (Ceiling)  : {w3.from_wei(decay.functions.startPrice().call(), 'ether')} $S / SLT")
print(f"Floor Reserve    : {w3.from_wei(decay.functions.floorPrice().call(), 'ether')} $S / SLT")
print(f"Current Price    : {w3.from_wei(decay.functions.getCurrentPrice().call(), 'ether')} $S / SLT")
print(f"Remaining Tokens : {w3.from_wei(decay.functions.remainingTokens().call(), 'ether')} SLT")
print(f"Total Funds Raised: {w3.from_wei(decay.functions.totalFundsRaised().call(), 'ether')} $S")
print(f"Buyers Count     : {decay.functions.buyersCount().call()}")
print(f"Auction Closed   : {decay.functions.auctionClosed().call()}")
