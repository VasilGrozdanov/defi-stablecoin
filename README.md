# 📄 Decentralized Stablecoin & DSC Engine Project

Welcome to the **Decentralized Stablecoin (DSC) and DSC Engine** project! This protocol is designed to create a trustless, algorithmic stablecoin pegged to USD using exogenous collateral, with built-in mechanisms for stability, liquidation, and incentives for maintaining over-collateralization.

## 🚀 Features
- **⚙️ Algorithmic Minting**: The stablecoin is minted algorithmically based on collateral.
- **📈 Pegged to USD**: The stablecoin maintains relative stability by being pegged to the US Dollar.
- **🛡️ Over-Collateralization**: The system requires a minimum of **50% over-collateralization** at all times to ensure solvency.
- **⛓️ Chainlink Price Feeds**: Collateral price is fetched in real-time using **Chainlink Price Feeds** to ensure accurate valuation.
- **⚖️ Liquidation Incentives**: Liquidators are incentivized with a **10% bonus reward** for liquidating under-collateralized positions, maintaining system health.

## 📊 Stability Mechanism
- **50% Over-Collateralization**: Users must maintain a collateral ratio above 150%. If the value of their collateral relative to the amount of stablecoin minted drops below 150%, their position is **eligible for liquidation**.
  
- **Partial or Full Liquidation**: When collateral drops and a user's minting exceeds **51% of their total collateral** (in USD), they can be partially or fully liquidated to safeguard the system.

- **Liquidator Incentives**: Liquidators are rewarded with **10% of the collateral** for liquidating bad debt, encouraging the community to keep the system solvent.

## 🔄 Collateral Types
The protocol supports a specific list of **pre-determined collateral tokens**. Only tokens from this list can be used to mint the stablecoin. The value of these tokens is always based on real-time data from **Chainlink Price Feeds**.

## ⚠️ Risk Factors
While the system is designed for stability, there are certain risks:
- **Stale Price Feeds**: If Chainlink's price feeds become stale, the protocol may face pricing inaccuracies.
- **Market Crashes**: A sudden, severe drop in collateral prices could eliminate financial incentives for liquidators, risking a protocol-wide failure.

## 🧠 How It Works

1. **Minting**: Users deposit exogenous collateral (e.g., wETH, wBTC) and mint stablecoins, ensuring they stay **50% over-collateralized**.
   
2. **Collateral Valuation**: Collateral is valued using **Chainlink Price Feeds**, keeping the system updated in real-time.

3. **Liquidation**: If the collateralization ratio falls below **150%**, the user’s position becomes eligible for liquidation. **Liquidators** get a **10% bonus** for clearing bad debt.

## 📚 Prerequisites
- **Solidity `0.8.19`**
- **[Foundry](https://book.getfoundry.sh/)**
- **[GNU Make](https://www.gnu.org/software/make/#download)**

## 🎯 Goals
- **Stability**: Maintain the USD peg with an algorithmic approach.
- **Incentives**: Encourage liquidators to act by rewarding them for maintaining healthy collateral levels.
- **Trustless Protocol**: Enable decentralized and transparent minting and liquidation processes.

---

Feel free to contribute to this project, and ensure you understand the associated risks before participating! 

## ⬇️ Installation

### Clone the repository:
```bash
git clone https://github.com/VasilGrozdanov/defi-stablecoin.git
```

## 🛠️ Usage

### 🔨 Build
Use the [Makefile](https://github.com/VasilGrozdanov/defi-stablecoin/blob/main/Makefile) commands **(📝 note: Make sure you have GNU Make installed and add the necessary environment variables in a `.env` file)**, or alternatively foundry commands:
```shell
$ forge build
```

### 🧪 Test

```shell
$ forge test
```

### 🎨 Format

```shell
$ forge fmt
```

### ⛽ Gas Snapshots

```shell
$ forge snapshot
```

### 🔧 Anvil

```shell
$ anvil
```

### 🚀 Deploy

```shell
$ forge script script/DeployRaffle.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```
> ⚠️ **Warning: Using your private key on a chain associated with real money must be avoided!**

 OR
```shell
$ forge script script/DeployRaffle.s.sol --rpc-url <your_rpc_url> --account <your_account> --broadcast
```
> 📝 **Note: Using your --account requires adding wallet first, which is more secure than the plain text private key!**
```Bash
cast wallet import --interactive <name_your_wallet>
```
### 🛠️ Cast

```shell
$ cast <subcommand>
```

### ❓ Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
