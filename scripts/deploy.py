#!/usr/bin/env python3
"""
Deploy script for SonicWinWinAuction to Sonic Testnet (Chain ID 14601)
"""

import sys
import os
import json
import subprocess
from web3 import Web3
from eth_account import Account

RPC_URL = "https://rpc.testnet.soniclabs.com"
CHAIN_ID = 14601

def deploy(private_key: str, feem_project_id: int = 0):
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    if not w3.is_connected():
        print(f"[!] Cannot connect to Sonic Testnet RPC: {RPC_URL}")
        return

    account = Account.from_key(private_key)
    print(f"[*] Deployer Address: {account.address}")
    balance = w3.eth.get_balance(account.address)
    print(f"[*] Deployer Balance: {w3.from_wei(balance, 'ether')} S")

    if balance < w3.to_wei('0.1', 'ether'):
        print("[!] Insufficient balance to deploy. Claim testnet faucet at: https://testnet.soniclabs.com/account")
        return

    # Compile with forge to get bytecode and abi
    print("[*] Compiling contracts with Forge...")
    subprocess.run(["forge", "build"], cwd=os.path.dirname(os.path.dirname(os.path.abspath(__file__))), check=True)

    out_file = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "out", "SonicWinWinAuction.sol", "SonicWinWinAuction.json")
    with open(out_file, "r") as f:
        artifact = json.load(f)

    abi = artifact["abi"]
    bytecode = artifact["bytecode"]["object"]

    Contract = w3.eth.contract(abi=abi, bytecode=bytecode)

    print("[*] Broadcasting deployment transaction...")
    construct_txn = Contract.constructor(feem_project_id).build_transaction({
        'from': account.address,
        'nonce': w3.eth.get_transaction_count(account.address),
        'value': w3.to_wei('0.1', 'ether'), # Seed 0.1 S to initial prize pot
        'gas': 2000000,
        'maxFeePerGas': w3.to_wei('55', 'gwei'),
        'maxPriorityFeePerGas': w3.to_wei('2', 'gwei'),
        'chainId': CHAIN_ID
    })

    signed = w3.eth.account.sign_transaction(construct_txn, private_key)
    tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
    print(f"[+] Deploy Tx Hash: {tx_hash.hex()}")
    print("[*] Awaiting sub-second block confirmation...")

    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    if receipt.status == 1:
        print(f"\n[✓] Success! Contract deployed to Sonic Testnet:")
        print(f"    Contract Address: {receipt.contractAddress}")
        print(f"    Explorer: https://testnet.sonicscan.org/address/{receipt.contractAddress}")
        print(f"\nTo launch the pacing bot:")
        print(f"    python scripts/bot.py {receipt.contractAddress} {private_key}")
    else:
        print("[x] Deployment transaction reverted.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python scripts/deploy.py <PRIVATE_KEY> [FEEM_PROJECT_ID]")
        sys.exit(1)

    pk = sys.argv[1]
    feem_id = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    deploy(pk, feem_id)
