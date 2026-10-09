# SonicFair: Batch Dutch Auction SDK on Sonic

Infrastruktur dan Developer SDK open-source untuk menyelenggarakan **Batch Dutch Auction dengan Uniform Clearing Price, 100% Lossless Bidding, dan Integrasi FeeM Native** di jaringan **Sonic**.

Siap diajukan ke **Sonic Labs Innovator Fund**.

---

## 🌐 Live Deployed Testnet Contracts (Sonic Testnet - Chain ID 14601)

* **Mode 1 Contract (Batch Uniform):** [`0x8b962894916a9bB298A766325319dEe4c2cc5AB0`](https://testnet.sonicscan.org/address/0x8b962894916a9bB298A766325319dEe4c2cc5AB0)
  * Multi-wallet live bidding simulation verified on-chain.
* **Mode 2 Contract (Continuous Time-Decay):** [`0xdf5B8E3AEB35c262ebd81216b985ede9a2c771c0`](https://testnet.sonicscan.org/address/0xdf5B8E3AEB35c262ebd81216b985ede9a2c771c0)
  * Real-time decaying purchase verified on-chain (Tx confirmed in block #19074369).
* **Sample Auction Token (SLT):** [`0x261eCcb3579061dee8458811edb44f39bf1e07A2`](https://testnet.sonicscan.org/address/0x261eCcb3579061dee8458811edb44f39bf1e07A2)

---

## 📁 Struktur Proyek & Deliverables

* `src/SonicBatchAuction.sol` — Engine 1: Batch Dutch Auction (Uniform Clearing Price, Anti-sniping, Per-Address Cap, 100% Refund, Integrasi FeeM Sonic).
* `src/SonicDecayingAuction.sol` — Engine 2: Continuous Time-Decaying Dutch Auction (Harga turun halus tiap detik/blok ~400ms, Auto-Change Refund, Early Sell-Out).
* `test/SonicBatchAuction.t.sol` — Test suite Foundry untuk Batch Mode (8 tests lolos + 256 fuzz runs).
* `test/SonicDecayingAuction.t.sol` — Test suite Foundry untuk Decaying Mode (6 tests lolos + 256 fuzz runs).
* `test/mocks/MockERC20.sol` — Mock token ERC20 untuk simulasi peluncuran token lelang.
* `scripts/simulate_auction.py` — Simulasi Monte Carlo memvalidasi 100 agen pembeli, membuktikan ketahanan terhadap bot sniping & manipulasi paus.
* `scripts/deploy_batch_auction.py` — Script 1-klik untuk deploy kontrak ke Sonic Testnet (Chain ID 14601).
* `scripts/simulate_testnet_bidding.py` — Simulator multi-wallet otomatis yang menghasilkan live bidding di testnet.
* `sdk/` — TypeScript SDK (`@sonicplay/batch-auction-sdk`) lengkap dengan type definitions untuk kedua engine lelang.
* `SONIC_INNOVATOR_PROPOSAL.md` — Dokumen proposal resmi siap kirim ke portal hibah Sonic Labs.
* `OUTREACH_EMAIL.md` — Draf pesan outreach resmi via Email dan Telegram untuk tim DevRel / BD Sonic.

---

## 🚀 Panduan Verifikasi & Eksekusi

### 1. Jalankan Seluruh Unit Test & Fuzzing (Foundry)
```bash
forge test -vv
```
*Hasil:* 18/18 tests lulus (100% passing rate di 3 test suite).

### 2. Jalankan Simulasi Berbasis Agen (Monte Carlo)
```bash
python scripts/simulate_auction.py
```
*Hasil:* Membuktikan secara matematis bahwa bot sniping dinetralisir oleh anti-snipe extension, paus dibatasi oleh address cap, dan peserta kalah mendapatkan refund 100%.

### 3. Deploy ke Sonic Blaze Testnet (Chain ID 57054)
Jika sudah memiliki private key wallet testnet dengan saldo $S (faucet dari https://testnet.soniclabs.com/account):
```bash
python scripts/deploy_batch_auction.py <YOUR_PRIVATE_KEY>
```
Script akan:
1. Mengompilasi kontrak dengan Forge.
2. Mendeploy token contoh (`MockERC20`).
3. Mendeploy `SonicBatchAuction.sol`.
4. Mendanai lelang dengan 10.000 token.
5. Menampilkan link explorer resmi di `https://testnet.sonicscan.org`.

### 4. Ajukan Proposal ke Sonic Labs
1. Buka form kontak resmi Sonic: **[https://www.soniclabs.com/contact](https://www.soniclabs.com/contact)** lalu pilih topik **`Request - Grant/ funding proposal`**.
2. Atau kirim email proposal langsung ke: **`bd@soniclabs.com`** (Cc: `build@soniclabs.com`).
3. Gunakan draf lengkap dari [`SONIC_INNOVATOR_PROPOSAL.md`](file:///c:/porto/11MYPORTO/CTF/scratch/sonic_winwin_auction/SONIC_INNOVATOR_PROPOSAL.md) dan panduan copy-paste di [`OUTREACH_EMAIL.md`](file:///c:/porto/11MYPORTO/CTF/scratch/sonic_winwin_auction/OUTREACH_EMAIL.md).
4. Hubungi komunitas developer di **[Builders Telegram (Invite Aktif)](https://t.me/+Mgg7txDrTs43MmM5)** atau Discord Sonic channel `#builders`.
