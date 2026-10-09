#!/usr/bin/env python3
"""
Deploy Script for SonicDecayingAuction (Continuous Time-Decay Mode) on Sonic Testnet.

Usage:
    python scripts/deploy_decaying_auction.py [PRIVATE_KEY]
"""

import sys
import os
import json
import time
import subprocess
from web3 import Web3

RPC_URL = os.getenv("SONIC_TESTNET_RPC", "https://rpc.testnet.soniclabs.com")
CHAIN_ID = 14601 # Sonic Testnet

def deploy(private_key: str):
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    if not w3.is_connected():
        print(f"[!] Cannot connect to Sonic RPC: {RPC_URL}")
        sys.exit(1)

    account = w3.eth.account.from_key(private_key)
    print("=" * 65)
    print("   SONIC DECAYING AUCTION DEPLOYMENT: SONIC TESTNET")
    print("=" * 65)
    print(f"[*] Deployer Address : {account.address}")
    
    balance = w3.eth.get_balance(account.address)
    print(f"[*] Balance          : {w3.from_wei(balance, 'ether'):.4f} $S")

    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    print("[*] Compiling contracts with forge...")
    subprocess.run(["forge", "build"], cwd=base_dir, check=True)

    # 1. Deploy or Re-use Token
    token_json_path = os.path.join(base_dir, "out", "MockERC20.sol", "MockERC20.json")
    with open(token_json_path, "r") as f:
        token_artifact = json.load(f)

    # Use existing token if known, or deploy new
    token_address = "0x532A16B1F019901aea016Db34d2aE4f0F30b675e"
    print(f"[*] 1. Using SLT Token Contract: {token_address}")

    # 2. Deploy SonicDecayingAuction
    decay_json_path = os.path.join(base_dir, "out", "SonicDecayingAuction.sol", "SonicDecayingAuction.json")
    with open(decay_json_path, "r") as f:
        decay_artifact = json.load(f)

    total_tokens = w3.to_wei(1000, 'ether')    # 1,000 SLT
    start_price = w3.to_wei(0.5, 'ether')      # 0.5 S start
    floor_price = w3.to_wei(0.01, 'ether')     # 0.01 S floor
    duration = 86400                           # 24 hours
    feem_project_id = 9999

    print("\n[*] 2. Deploying SonicDecayingAuction Contract...")
    decay_contract = w3.eth.contract(abi=decay_artifact["abi"], bytecode=decay_artifact["bytecode"]["object"])
    nonce = w3.eth.get_transaction_count(account.address)

    tx_deploy = decay_contract.constructor(
        token_address,
        total_tokens,
        start_price,
        floor_price,
        duration,
        feem_project_id
    ).build_transaction({
        'from': account.address,
        'nonce': nonce,
        'gas': 3000000,
        'gasPrice': w3.eth.gas_price,
        'chainId': CHAIN_ID
    })
    signed_deploy = w3.eth.account.sign_transaction(tx_deploy, private_key)
    tx_hash = w3.eth.send_raw_transaction(signed_deploy.raw_transaction)
    print(f"    Tx Hash: {tx_hash.hex()}")
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    auction_address = receipt.contractAddress
    print(f"    Auction Deployed: {auction_address}")

    # 3. Mint and Fund 1,000 Tokens
    print("\n[*] 3. Minting and Funding 1,000 SLT into Decaying Auction...")
    token_inst = w3.eth.contract(address=token_address, abi=token_artifact["abi"])
    nonce = w3.eth.get_transaction_count(account.address)

    # Mint
    tx_mint = token_inst.functions.mint(account.address, total_tokens).build_transaction({
        'from': account.address,
        'nonce': nonce,
        'gas': 200000,
        'gasPrice': w3.eth.gas_price,
        'chainId': CHAIN_ID
    })
    signed_mint = w3.eth.account.sign_transaction(tx_mint, private_key)
    w3.eth.send_raw_transaction(signed_mint.raw_transaction)
    w3.eth.wait_for_transaction_receipt(signed_mint.hash)

    # Approve
    nonce += 1
    tx_app = token_inst.functions.approve(auction_address, total_tokens).build_transaction({
        'from': account.address,
        'nonce': nonce,
        'gas': 200000,
        'gasPrice': w3.eth.gas_price,
        'chainId': CHAIN_ID
    })
    signed_app = w3.eth.account.sign_transaction(tx_app, private_key)
    w3.eth.send_raw_transaction(signed_app.raw_transaction)
    w3.eth.wait_for_transaction_receipt(signed_app.hash)

    # Deposit
    nonce += 1
    auction_inst = w3.eth.contract(address=auction_address, abi=decay_artifact["abi"])
    tx_dep = auction_inst.functions.depositOfferedTokens().build_transaction({
        'from': account.address,
        'nonce': nonce,
        'gas': 300000,
        'gasPrice': w3.eth.gas_price,
        'chainId': CHAIN_ID
    })
    signed_dep = w3.eth.account.sign_transaction(tx_dep, private_key)
    w3.eth.send_raw_transaction(signed_dep.raw_transaction)
    w3.eth.wait_for_transaction_receipt(signed_dep.hash)

    print("\n" + "=" * 65)
    print(" [OK] SUCCESS! SonicDecayingAuction Deployed and Fully Funded!")
    print("=" * 65)
    print(f"  Auction Contract : {auction_address}")
    print(f"  Token Contract   : {token_address}")
    print(f"  Explorer Link    : https://testnet.sonicscan.org/address/{auction_address}")
    print(f"  Start Price      : {w3.from_wei(start_price, 'ether')} $S")
    print(f"  Floor Price      : {w3.from_wei(floor_price, 'ether')} $S")
    print(f"  Chain ID         : {CHAIN_ID} (Sonic Testnet)")

    return auction_address

if __name__ == "__main__":
    pk = None
    if len(sys.argv) >= 2:
        pk = sys.argv[1]
    else:
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
        print("Usage: python scripts/deploy_decaying_auction.py <PRIVATE_KEY>")
        sys.exit(1)

    if not pk.startswith("0x"):
        pk = "0x" + pk

    deploy(pk)
