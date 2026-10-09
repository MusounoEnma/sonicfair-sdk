/**
 * SonicFair Developer SDK
 * Dual-Engine Auction Architecture for Sonic:
 * 1. SonicBatchAuctionClient: Batch Dutch Auction with Uniform Clearing Price (DeFi / Fair Launch)
 * 2. SonicDecayingAuctionClient: Continuous Time-Decaying Dutch Auction (Gaming / Flash / NFT Drop)
 */

export const SONIC_TESTNET_CHAIN_ID = 14601;
export const SONIC_BLAZE_TESTNET_CHAIN_ID = 57054;
export const SONIC_MAINNET_CHAIN_ID = 146;

// ==========================================
// 1. BATCH UNIFORM AUCTION
// ==========================================

export const SONIC_BATCH_AUCTION_ABI = [
  "function seller() view returns (address)",
  "function tokenOffered() view returns (address)",
  "function totalTokensOffered() view returns (uint256)",
  "function reservePrice() view returns (uint256)",
  "function maxBidPerAddress() view returns (uint256)",
  "function antiSnipeWindow() view returns (uint256)",
  "function antiSnipeExtension() view returns (uint256)",
  "function auctionStartTime() view returns (uint256)",
  "function auctionEndTime() view returns (uint256)",
  "function settled() view returns (bool)",
  "function clearingPrice() view returns (uint256)",
  "function totalWinningFunds() view returns (uint256)",
  "function totalTokensSold() view returns (uint256)",
  "function calculateClearingPrice() view returns (uint256 estPrice, uint256 cutoff, uint256 winningFunds, uint256 tokensSold)",
  "function placeBid(uint256 _maxPricePerToken, uint256 _hintIndex) payable",
  "function settleAuction()",
  "function claim(uint256 bidId)",
  "function claimAll()",
  "function getUserBids(address user) view returns (uint256[])",
  "function totalBidsCount() view returns (uint256)",
  "function registerFeeM()"
] as const;

export interface BatchAuctionState {
  seller: string;
  tokenOffered: string;
  totalTokensOffered: bigint;
  reservePrice: bigint;
  maxBidPerAddress: bigint;
  startTime: number;
  endTime: number;
  settled: boolean;
  clearingPrice: bigint;
  totalWinningFunds: bigint;
  totalTokensSold: bigint;
  totalBidsCount: number;
}

export interface ClearingPriceEstimate {
  estimatedPrice: bigint;
  cutoffIndex: number;
  winningFunds: bigint;
  tokensSold: bigint;
}

export class SonicBatchAuctionClient {
  constructor(
    public readonly contractAddress: string,
    public readonly providerOrSigner: any
  ) {}

  async getAuctionState(): Promise<BatchAuctionState> {
    const contract = this.getContract(SONIC_BATCH_AUCTION_ABI);
    const [
      seller, tokenOffered, totalTokensOffered, reservePrice, maxBidPerAddress,
      startTime, endTime, settled, clearingPrice, winningFunds, sold, bidsCount
    ] = await Promise.all([
      contract.seller(), contract.tokenOffered(), contract.totalTokensOffered(),
      contract.reservePrice(), contract.maxBidPerAddress(), contract.auctionStartTime(),
      contract.auctionEndTime(), contract.settled(), contract.clearingPrice(),
      contract.totalWinningFunds(), contract.totalTokensSold(), contract.totalBidsCount()
    ]);

    return {
      seller, tokenOffered,
      totalTokensOffered: BigInt(totalTokensOffered),
      reservePrice: BigInt(reservePrice),
      maxBidPerAddress: BigInt(maxBidPerAddress),
      startTime: Number(startTime),
      endTime: Number(endTime),
      settled: Boolean(settled),
      clearingPrice: BigInt(clearingPrice),
      totalWinningFunds: BigInt(winningFunds),
      totalTokensSold: BigInt(sold),
      totalBidsCount: Number(bidsCount)
    };
  }

  async getClearingPriceEstimate(): Promise<ClearingPriceEstimate> {
    const contract = this.getContract(SONIC_BATCH_AUCTION_ABI);
    const res = await contract.calculateClearingPrice();
    return {
      estimatedPrice: BigInt(res[0]),
      cutoffIndex: Number(res[1]),
      winningFunds: BigInt(res[2]),
      tokensSold: BigInt(res[3])
    };
  }

  async placeBid(amountWei: bigint, maxPricePerTokenWei: bigint, hintIndex: number = 0): Promise<any> {
    const contract = this.getContract(SONIC_BATCH_AUCTION_ABI);
    return await contract.placeBid(maxPricePerTokenWei, hintIndex, { value: amountWei });
  }

  async settle(): Promise<any> {
    const contract = this.getContract(SONIC_BATCH_AUCTION_ABI);
    return await contract.settleAuction();
  }

  async claimAll(): Promise<any> {
    const contract = this.getContract(SONIC_BATCH_AUCTION_ABI);
    return await contract.claimAll();
  }

  async getUserBids(userAddress: string): Promise<bigint[]> {
    const contract = this.getContract(SONIC_BATCH_AUCTION_ABI);
    const bids = await contract.getUserBids(userAddress);
    return bids.map((b: any) => BigInt(b));
  }

  private getContract(abi: any): any {
    if (this.providerOrSigner.call || this.providerOrSigner.sendTransaction) {
      const { Contract } = require("ethers");
      return new Contract(this.contractAddress, abi, this.providerOrSigner);
    }
    return this.providerOrSigner;
  }
}

// ==========================================
// 2. TIME-DECAYING DUTCH AUCTION (FLASH & GAMING)
// ==========================================

export const SONIC_DECAYING_AUCTION_ABI = [
  "function seller() view returns (address)",
  "function tokenOffered() view returns (address)",
  "function totalTokensOffered() view returns (uint256)",
  "function remainingTokens() view returns (uint256)",
  "function startPrice() view returns (uint256)",
  "function floorPrice() view returns (uint256)",
  "function startTime() view returns (uint256)",
  "function endTime() view returns (uint256)",
  "function duration() view returns (uint256)",
  "function auctionClosed() view returns (bool)",
  "function totalFundsRaised() view returns (uint256)",
  "function totalTokensSold() view returns (uint256)",
  "function buyersCount() view returns (uint256)",
  "function getCurrentPrice() view returns (uint256)",
  "function buyTokens() payable",
  "function closeAuction()"
] as const;

export interface DecayingAuctionState {
  seller: string;
  tokenOffered: string;
  totalTokensOffered: bigint;
  remainingTokens: bigint;
  startPrice: bigint;
  floorPrice: bigint;
  currentPrice: bigint;
  startTime: number;
  endTime: number;
  auctionClosed: boolean;
  totalFundsRaised: bigint;
  totalTokensSold: bigint;
  buyersCount: number;
}

export class SonicDecayingAuctionClient {
  constructor(
    public readonly contractAddress: string,
    public readonly providerOrSigner: any
  ) {}

  async getCurrentPrice(): Promise<bigint> {
    const contract = this.getContract(SONIC_DECAYING_AUCTION_ABI);
    const price = await contract.getCurrentPrice();
    return BigInt(price);
  }

  async getAuctionState(): Promise<DecayingAuctionState> {
    const contract = this.getContract(SONIC_DECAYING_AUCTION_ABI);
    const [
      seller, tokenOffered, totalTokensOffered, remainingTokens,
      startPrice, floorPrice, curPrice, startTime, endTime,
      auctionClosed, totalFundsRaised, totalTokensSold, buyersCount
    ] = await Promise.all([
      contract.seller(), contract.tokenOffered(), contract.totalTokensOffered(),
      contract.remainingTokens(), contract.startPrice(), contract.floorPrice(),
      contract.getCurrentPrice(), contract.startTime(), contract.endTime(),
      contract.auctionClosed(), contract.totalFundsRaised(), contract.totalTokensSold(),
      contract.buyersCount()
    ]);

    return {
      seller, tokenOffered,
      totalTokensOffered: BigInt(totalTokensOffered),
      remainingTokens: BigInt(remainingTokens),
      startPrice: BigInt(startPrice),
      floorPrice: BigInt(floorPrice),
      currentPrice: BigInt(curPrice),
      startTime: Number(startTime),
      endTime: Number(endTime),
      auctionClosed: Boolean(auctionClosed),
      totalFundsRaised: BigInt(totalFundsRaised),
      totalTokensSold: BigInt(totalTokensSold),
      buyersCount: Number(buyersCount)
    };
  }

  async buyTokens(amountWei: bigint): Promise<any> {
    const contract = this.getContract(SONIC_DECAYING_AUCTION_ABI);
    return await contract.buyTokens({ value: amountWei });
  }

  async closeAuction(): Promise<any> {
    const contract = this.getContract(SONIC_DECAYING_AUCTION_ABI);
    return await contract.closeAuction();
  }

  private getContract(abi: any): any {
    if (this.providerOrSigner.call || this.providerOrSigner.sendTransaction) {
      const { Contract } = require("ethers");
      return new Contract(this.contractAddress, abi, this.providerOrSigner);
    }
    return this.providerOrSigner;
  }
}
