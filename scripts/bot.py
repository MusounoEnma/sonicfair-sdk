#!/usr/bin/env python3
"""
SonicWinWinAuction Autonomous Pacing & Activity Bot
Simulates live bidding wars, keeps rounds active, and showcases Sonic's sub-second finality.
"""

import time
import os
import sys
from web3 import Web3
from eth_account import Account

# Sonic Testnet Configuration
RPC_URL = os.getenv("SONIC_TESTNET_RPC", "https://rpc.testnet.soniclabs.com")
CHAIN_ID = 14601

# Contract ABI minimal
ABI = [
    {
        "inputs": [],
        "name": "getCurrentRoundInfo",
        "outputs": [
            {"internalType": "uint256", "name": "roundId", "type": "uint256"},
            {"internalType": "uint256", "name": "timeRemaining", "type": "uint256"},
            {"internalType": "address", "name": "topBidder", "type": "address"},
            {"internalType": "uint256", "name": "topBid", "type": "uint256"},
            {"internalType": "uint256", "name": "prizePot", "type": "uint256"},
            {"internalType": "uint256", "name": "minNextBid", "type": "uint256"},
            {"internalType": "uint256", "name": "bidCount", "type": "uint256"}
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "placeBid",
        "outputs": [],
        "stateMutability": "payable",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "settleAndNextRound",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    }
]

def run_bot(contract_address: str, private_key: str):
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    if not w3.is_connected():
        print(f"[!] Error: Could not connect to Sonic Testnet at {RPC_URL}")
        return

    account = Account.from_key(private_key)
    contract = w3.eth.contract(address=Web3.to_checksum_address(contract_address), abi=ABI)

    print(f"=== Sonic Win-Win Auction Autonomous Bot ===")
    print(f"[*] Connected to Sonic Testnet (Chain ID: {CHAIN_ID})")
    print(f"[*] Bot Wallet: {account.address}")
    balance = w3.eth.get_balance(account.address)
    print(f"[*] Wallet Balance: {w3.from_wei(balance, 'ether')} S")
    print(f"[*] Target Contract: {contract_address}")
    print("=" * 45)

    while True:
        try:
            info = contract.functions.getCurrentRoundInfo().call()
            round_id = info[0]
            remaining = info[1]
            top_bidder = info[2]
            top_bid = info[3]
            prize_pot = info[4]
            min_next_bid = info[5]
            bid_count = info[6]

            print(f"[Round #{round_id}] Time Left: {remaining}s | Bids: {bid_count} | Pot: {w3.from_wei(prize_pot, 'ether')} S | Min Bid: {w3.from_wei(min_next_bid, 'ether')} S")

            # Condition 1: Round expired -> Settle
            if remaining == 0:
                print(f"[*] Round #{round_id} ended! Executing settleAndNextRound()...")
                tx = contract.functions.settleAndNextRound().build_transaction({
                    'from': account.address,
                    'nonce': w3.eth.get_transaction_count(account.address),
                    'gas': 300000,
                    'maxFeePerGas': w3.to_wei('55', 'gwei'),
                    'maxPriorityFeePerGas': w3.to_wei('2', 'gwei'),
                    'chainId': CHAIN_ID
                })
                signed = w3.eth.account.sign_transaction(tx, private_key)
                tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
                print(f"[+] Settle Tx Sent: {tx_hash.hex()} (Waiting confirmation...)")
                w3.eth.wait_for_transaction_receipt(tx_hash)
                print(f"[✓] New round started successfully!")
                time.sleep(3)
                continue

            # Condition 2: Bot is not the top bidder and wants to pace the auction
            if top_bidder.lower() != account.address.lower():
                # Check if wallet has sufficient balance
                if balance > min_next_bid + w3.to_wei('0.01', 'ether'):
                    print(f"[*] Bot submitting bid: {w3.from_wei(min_next_bid, 'ether')} S...")
                    tx = contract.functions.placeBid().build_transaction({
                        'from': account.address,
                        'value': min_next_bid,
                        'nonce': w3.eth.get_transaction_count(account.address),
                        'gas': 250000,
                        'maxFeePerGas': w3.to_wei('55', 'gwei'),
                        'maxPriorityFeePerGas': w3.to_wei('2', 'gwei'),
                        'chainId': CHAIN_ID
                    })
                    signed = w3.eth.account.sign_transaction(tx, private_key)
                    tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
                    print(f"[+] Bid Tx Sent: {tx_hash.hex()}")
                    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
                    if receipt.status == 1:
                        print(f"[✓] Bid confirmed in block #{receipt.blockNumber} (Sub-second execution)!")
                    else:
                        print(f"[x] Bid transaction reverted.")
                else:
                    print(f"[!] Bot balance insufficient for next bid increment.")

            # Sleep interval
            time.sleep(5)

        except KeyboardInterrupt:
            print("\n[*] Bot stopped by user.")
            break
        except Exception as e:
            print(f"[!] Error loop: {e}")
            time.sleep(5)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage:")
        print("  python bot.py <CONTRACT_ADDRESS> <PRIVATE_KEY>")
        print("\nExample:")
        print("  python bot.py 0x1234...5678 0xabc...def")
        sys.exit(1)

    contract_addr = sys.argv[1]
    priv_key = sys.argv[2]
    run_bot(contract_addr, priv_key)
