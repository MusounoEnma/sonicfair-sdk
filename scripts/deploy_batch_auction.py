#!/usr/bin/env python3
"""
Deploy Script for SonicBatchAuction on Sonic Blaze Testnet (Chain ID 57054)

Usage:
    python scripts/deploy_batch_auction.py <PRIVATE_KEY>
"""

import sys
import os
import json
import subprocess
from web3 import Web3

RPC_URL = os.getenv("SONIC_TESTNET_RPC", "https://rpc.testnet.soniclabs.com")
CHAIN_ID = 14601 # Sonic Testnet

def deploy(private_key: str):
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    if not w3.is_connected():
        print(f"[!] Cannot connect to Sonic Blaze RPC: {RPC_URL}")
        sys.exit(1)

    account = w3.eth.account.from_key(private_key)
    print("=" * 60)
    print("    SONIC BATCH AUCTION DEPLOYMENT: SONIC BLAZE TESTNET")
    print("=" * 60)
    print(f"[*] Deployer Address : {account.address}")
    
    balance = w3.eth.get_balance(account.address)
    balance_s = w3.from_wei(balance, 'ether')
    print(f"[*] Balance          : {balance_s:.4f} $S")

    if balance < w3.to_wei(0.05, 'ether'):
        print("[!] Balance too low to deploy. Get faucet at: https://testnet.soniclabs.com/account")
        sys.exit(1)

    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    print("[*] Compiling contracts with forge...")
    subprocess.run(["forge", "build"], cwd=base_dir, check=True)

    # 1. Deploy Mock Token
    token_json_path = os.path.join(base_dir, "out", "MockERC20.sol", "MockERC20.json")
    with open(token_json_path, "r") as f:
        token_artifact = json.load(f)

    print("\n[*] 1. Deploying Mock Token (SLT)...")
    token_contract = w3.eth.contract(abi=token_artifact["abi"], bytecode=token_artifact["bytecode"]["object"])
    nonce = w3.eth.get_transaction_count(account.address)

    tx1 = token_contract.constructor().build_transaction({
        'from': account.address,
        'nonce': nonce,
        'gas': 2000000,
        'gasPrice': w3.eth.gas_price,
        'chainId': CHAIN_ID
    })
    signed1 = w3.eth.account.sign_transaction(tx1, private_key)
    tx1_hash = w3.eth.send_raw_transaction(signed1.raw_transaction)
    print(f"    Tx Hash: {tx1_hash.hex()}")
    receipt1 = w3.eth.wait_for_transaction_receipt(tx1_hash)
    token_address = receipt1.contractAddress
    print(f"    Token Deployed: {token_address}")

    # 2. Deploy SonicBatchAuction
    auction_json_path = os.path.join(base_dir, "out", "SonicBatchAuction.sol", "SonicBatchAuction.json")
    with open(auction_json_path, "r") as f:
        auction_artifact = json.load(f)

    total_tokens = w3.to_wei(10000, 'ether')   # 10,000 SLT
    reserve_price = w3.to_wei(0.01, 'ether')  # 0.01 S
    duration = 86400                          # 24 hours
    max_bid_cap = w3.to_wei(500, 'ether')     # 500 S cap
    anti_snipe_window = 300                   # 5 minutes
    anti_snipe_ext = 300                      # 5 minutes
    feem_project_id = 9999

    print("\n[*] 2. Deploying SonicBatchAuction Contract...")
    auction_contract = w3.eth.contract(abi=auction_artifact["abi"], bytecode=auction_artifact["bytecode"]["object"])
    nonce = w3.eth.get_transaction_count(account.address)

    tx2 = auction_contract.constructor(
        token_address,
        total_tokens,
        reserve_price,
        duration,
        max_bid_cap,
        anti_snipe_window,
        anti_snipe_ext,
        feem_project_id
    ).build_transaction({
        'from': account.address,
        'nonce': nonce,
        'gas': 3500000,
        'gasPrice': w3.eth.gas_price,
        'chainId': CHAIN_ID
    })
    signed2 = w3.eth.account.sign_transaction(tx2, private_key)
    tx2_hash = w3.eth.send_raw_transaction(signed2.raw_transaction)
    receipt2 = w3.eth.wait_for_transaction_receipt(tx2_hash)
    auction_address = receipt2.contractAddress
    print(f"    Auction Deployed: {auction_address}")

    # 3. Mint and Fund Tokens to Auction
    print("\n[*] 3. Minting and Funding 10,000 SLT to Auction...")
    token_inst = w3.eth.contract(address=token_address, abi=token_artifact["abi"])
    nonce = w3.eth.get_transaction_count(account.address)

    # Mint to seller
    tx3 = token_inst.functions.mint(account.address, total_tokens).build_transaction({
        'from': account.address,
        'nonce': nonce,
        'gas': 200000,
        'gasPrice': w3.eth.gas_price,
        'chainId': CHAIN_ID
    })
    signed3 = w3.eth.account.sign_transaction(tx3, private_key)
    w3.eth.send_raw_transaction(signed3.raw_transaction)
    w3.eth.wait_for_transaction_receipt(signed3.hash)

    # Approve auction
    nonce += 1
    tx4 = token_inst.functions.approve(auction_address, total_tokens).build_transaction({
        'from': account.address,
        'nonce': nonce,
        'gas': 200000,
        'gasPrice': w3.eth.gas_price,
        'chainId': CHAIN_ID
    })
    signed4 = w3.eth.account.sign_transaction(tx4, private_key)
    w3.eth.send_raw_transaction(signed4.raw_transaction)
    w3.eth.wait_for_transaction_receipt(signed4.hash)

    # Deposit into auction
    nonce += 1
    auction_inst = w3.eth.contract(address=auction_address, abi=auction_artifact["abi"])
    tx5 = auction_inst.functions.depositOfferedTokens().build_transaction({
        'from': account.address,
        'nonce': nonce,
        'gas': 300000,
        'gasPrice': w3.eth.gas_price,
        'chainId': CHAIN_ID
    })
    signed5 = w3.eth.account.sign_transaction(tx5, private_key)
    w3.eth.send_raw_transaction(signed5.raw_transaction)
    w3.eth.wait_for_transaction_receipt(signed5.hash)

    print("\n" + "=" * 60)
    print(" [OK] SUCCESS! SonicBatchAuction Deployed and Fully Funded!")
    print("=" * 60)
    print(f"  Auction Contract : {auction_address}")
    print(f"  Token Contract   : {token_address}")
    print(f"  Explorer Link    : https://testnet.sonicscan.org/address/{auction_address}")
    print(f"  Chain ID         : {CHAIN_ID} (Sonic Blaze Testnet)")

if __name__ == "__main__":
    pk = None
    if len(sys.argv) >= 2:
        pk = sys.argv[1]
    else:
        # Check default key.txt locations
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
                print(f"[*] Loaded private key from: {kpath}")
                break

    if not pk:
        print("Usage: python scripts/deploy_batch_auction.py <YOUR_PRIVATE_KEY>")
        sys.exit(1)

    if not pk.startswith("0x"):
        pk = "0x" + pk

    deploy(pk)
