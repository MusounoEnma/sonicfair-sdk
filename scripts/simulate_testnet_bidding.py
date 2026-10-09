#!/usr/bin/env python3
"""
Multi-Wallet Automated Bidding Simulator for SonicBatchAuction on Sonic Blaze Testnet.

Features:
1. Takes 1 master wallet (deployer).
2. Automatically generates 3-5 sub-wallets (Alice, Bob, Charlie, etc.).
3. Funds each sub-wallet with a small drip of $S for bidding.
4. Each sub-wallet places realistic bids with different maxPrice levels.
5. Monitors clearing price updates in real-time.
6. Automatically sweeps remaining balances back to the master wallet.
"""

import sys
import os
import json
import time
from web3 import Web3
from eth_account import Account

RPC_URL = os.getenv("SONIC_TESTNET_RPC", "https://rpc.testnet.soniclabs.com")
CHAIN_ID = 14601 # Sonic Testnet

def simulate_bidding(master_pk: str, auction_address: str, num_bots: int = 3):
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    if not w3.is_connected():
        print(f"[!] Cannot connect to Sonic Blaze RPC: {RPC_URL}")
        sys.exit(1)

    master = Account.from_key(master_pk)
    print("=" * 65)
    print("   SONIC BATCH AUCTION: MULTI-WALLET LIVE SIMULATOR")
    print("=" * 65)
    print(f"[*] Master Wallet   : {master.address}")
    
    master_bal = w3.eth.get_balance(master.address)
    print(f"[*] Master Balance  : {w3.from_wei(master_bal, 'ether'):.4f} $S")

    if master_bal < w3.to_wei(0.1, 'ether'):
        print("[!] Master wallet balance is low (needs at least 0.1 $S).")
        sys.exit(1)

    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    json_path = os.path.join(base_dir, "out", "SonicBatchAuction.sol", "SonicBatchAuction.json")
    with open(json_path, "r") as f:
        artifact = json.load(f)

    contract = w3.eth.contract(
        address=Web3.to_checksum_address(auction_address),
        abi=artifact["abi"]
    )

    reserve_price = contract.functions.reservePrice().call()
    print(f"[*] Reserve Price   : {w3.from_wei(reserve_price, 'ether')} $S / token")
    print(f"[*] Generating {num_bots} autonomous bidder wallets...")

    # 1. Generate Sub-Wallets
    bots = []
    bot_names = ["Alice", "Bob", "Charlie", "Dave", "Eve"]
    for i in range(num_bots):
        bot_acc = Account.create()
        name = bot_names[i] if i < len(bot_names) else f"Bot_{i+1}"
        bots.append({"name": name, "account": bot_acc})
        print(f"    - [{name}] {bot_acc.address}")

    # 2. Fund Sub-Wallets (drip 0.1 S each)
    drip_amount = w3.to_wei(0.1, 'ether')
    print(f"\n[*] Funding each bot with {w3.from_wei(drip_amount, 'ether')} $S from Master Wallet...")
    master_nonce = w3.eth.get_transaction_count(master.address)

    fund_hashes = []
    for bot in bots:
        tx = {
            'to': bot["account"].address,
            'value': drip_amount,
            'gas': 21000,
            'gasPrice': w3.eth.gas_price,
            'nonce': master_nonce,
            'chainId': CHAIN_ID
        }
        signed = w3.eth.account.sign_transaction(tx, master_pk)
        tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
        fund_hashes.append(tx_hash)
        print(f"    Funding {bot['name']} -> Tx: {tx_hash.hex()[:18]}...")
        master_nonce += 1

    # Wait for all funding receipts
    for h in fund_hashes:
        w3.eth.wait_for_transaction_receipt(h)
    print("    [OK] All bots funded and confirmed!")

    # 3. Each Bot Places a Bid with Different Valuations
    print("\n[*] Bots placing bids with dynamic price limits...")
    price_multipliers = [1.5, 2.5, 4.0, 5.0, 3.0]

    for idx, bot in enumerate(bots):
        multiplier = price_multipliers[idx % len(price_multipliers)]
        max_price = int(reserve_price * multiplier)
        bid_value = w3.to_wei(0.02, 'ether') # 0.02 S bid

        bot_nonce = w3.eth.get_transaction_count(bot["account"].address)
        bid_tx = contract.functions.placeBid(max_price, 0).build_transaction({
            'from': bot["account"].address,
            'value': bid_value,
            'gas': 350000,
            'gasPrice': w3.eth.gas_price,
            'nonce': bot_nonce,
            'chainId': CHAIN_ID
        })
        signed_bid = w3.eth.account.sign_transaction(bid_tx, bot["account"].key)
        bid_hash = w3.eth.send_raw_transaction(signed_bid.raw_transaction)
        print(f"    [Bid Placed] {bot['name']} bid {w3.from_wei(bid_value, 'ether')} $S (Max: {w3.from_wei(max_price, 'ether')} $S/SLT) -> Tx: {bid_hash.hex()}")
        w3.eth.wait_for_transaction_receipt(bid_hash)

    # 4. Read Live Market Clearing Price
    print("\n[*] Fetching Real-Time Market Clearing Price from Contract...")
    time.sleep(1)
    est_price, cutoff, winning_funds, tokens_sold = contract.functions.calculateClearingPrice().call()
    total_bids = contract.functions.totalBidsCount().call()

    print(f"    - Total Bids in Contract  : {total_bids}")
    print(f"    - Current Clearing Price  : {w3.from_wei(est_price, 'ether')} $S")
    print(f"    - Winning Bids Count      : {cutoff}")
    print(f"    - Winning Capital Raised  : {w3.from_wei(winning_funds, 'ether')} $S")
    print(f"    - Tokens Sold             : {w3.from_wei(tokens_sold, 'ether')} SLT")

    # 5. Sweep Remaining Funds Back to Master
    print("\n[*] Sweeping remaining dust/funds from bots back to Master Wallet...")
    for bot in bots:
        bot_bal = w3.eth.get_balance(bot["account"].address)
        gas_cost = w3.eth.gas_price * 21000
        if bot_bal > gas_cost:
            sweep_val = bot_bal - gas_cost
            tx = {
                'to': master.address,
                'value': sweep_val,
                'gas': 21000,
                'gasPrice': w3.eth.gas_price,
                'nonce': w3.eth.get_transaction_count(bot["account"].address),
                'chainId': CHAIN_ID
            }
            signed_sweep = w3.eth.account.sign_transaction(tx, bot["account"].key)
            w3.eth.send_raw_transaction(signed_sweep.raw_transaction)
            print(f"    Swept {w3.from_wei(sweep_val, 'ether'):.4f} $S from {bot['name']} to Master.")

    print("\n[OK] Multi-Wallet Simulation Successfully Executed on Sonic Blaze Testnet!")

if __name__ == "__main__":
    pk = None
    addr = None
    bots_count = 3

    # Always attempt to load master pk from key.txt first
    possible_keys = [
        "c:/porto/11MYPORTO/CTF/key.txt",
        os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))), "key.txt"),
        os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "key.txt"),
        os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "key.txt"),
        "key.txt"
    ]
    for kpath in possible_keys:
        if os.path.exists(kpath):
            with open(kpath, "r") as f:
                pk = f.read().strip()
            print(f"[*] Loaded master private key from: {kpath}")
            break

    args = sys.argv[1:]
    # Check if first arg is an address (42 chars, starts with 0x)
    for a in args:
        if len(a) == 42 and a.startswith("0x"):
            addr = a
        elif a.isdigit():
            bots_count = int(a)
        elif len(a) == 64 or (len(a) == 66 and a.startswith("0x")):
            pk = a

    if not pk or not addr:
        print("Usage: python scripts/simulate_testnet_bidding.py <AUCTION_ADDRESS> [NUM_BOTS]")
        print("   or: python scripts/simulate_testnet_bidding.py <MASTER_PRIVATE_KEY> <AUCTION_ADDRESS> [NUM_BOTS]")
        sys.exit(1)

    if not pk.startswith("0x"):
        pk = "0x" + pk

    simulate_bidding(pk, addr, bots_count)
