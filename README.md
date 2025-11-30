# Zotto
ZLOT is a next-gen token featuring a VRF-powered lottery, auto-compounding staking, and the first burn-to-win system where burning gives permanent lifetime lottery power. 
Buy for daily tickets, burn for eternal advantage—rewarding every interaction.


# ZLOT – Burn-to-Win Lottery Token & Auto-Compounding Staking Vault

ZLOT is an innovative token ecosystem combining on-chain lotteries, staking, taxes, and a unique **Burn-to-Win** system that rewards you permanently for burning tokens.  
Buying grants daily lottery tickets, burning grants lifetime lottery power, and staking yields compounding rewards funded by the protocol.

Chainlink VRF ensures every jackpot draw is fair and verifiable.

---

## 🚀 Key Innovations

### 🔥 Burn-to-Win (Permanent Benefit)
Burning ZLOT increases your **permanent lottery weight**.  
This weight never resets and counts in **every** future jackpot.

### 🎟️ Buy-to-Win (Daily Reset)
Buying tokens adds you to the **daily lottery pool**.  
These entries reset after each jackpot cycle, keeping the game dynamic.

### 🎰 VRF Lottery
Uses Chainlink VRF V2 to select a random, tamper-proof jackpot winner.

### 💧 Tax Allocation
Every transfer fuels:
- Jackpot pool  
- Liquidity pool  
- Staking rewards  
- Marketing  
- Quests  
- Burn incentives  

### 📈 Auto-Compounding Staking Vault
A portion of taxes goes to a second contract — the **Staking Vault**.  
It distributes rewards automatically whenever someone stakes or unstakes.

---

## 🏗 Deployment Guide (IMPORTANT)

You **must deploy and configure both contracts correctly** for the system to function.

### **1️⃣ Deploy Contract 1 — ZLOT Token + Lottery**
Deploy the main token contract first.  
Copy the deployed address.

---

### **2️⃣ Deploy Contract 2 — Staking Vault**
When deploying Contract 2, pass the address of Contract 1 into its constructor:

```solidity
TokenInterface(<Contract1_Address>)
```
Copy the deployed address.

---

### **2️⃣ Set Staking Vault address in ZLOT Token + Lottery Contract**

call setStakersWallet function and pass StakingVault's Contract's Address

