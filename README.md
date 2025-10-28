# 🔮 Prediction Market DApp

A decentralized prediction market platform built on Ethereum that allows users to create markets, place bets on future events, and earn rewards for correct predictions.

## 📋 Table of Contents

- [Features](#features)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Testing](#testing)
- [Usage](#usage)
- [Smart Contract Functions](#smart-contract-functions)
- [Frontend Features](#frontend-features)
- [Security Features](#security-features)
- [Bonus Features Implemented](#bonus-features-implemented)
- [Course Requirements Fulfilled](#course-requirements-fulfilled)

## ✨ Features

### Core Features

- **Market Creation**: Users can create new prediction markets with custom descriptions, outcomes, and resolution times
- **Betting System**: Users can place bets on different outcomes using ETH
- **Market Resolution**: Designated arbitrators can resolve markets and determine winning outcomes
- **Winnings Distribution**: Winners can withdraw their proportional share of the total bet pool
- **Market Discovery**: Browse active and resolved markets with real-time probability calculations

<!-- ### Bonus Features
- **Dynamic Pricing**: Market prices reflect the wisdom of the crowd through betting volumes
- **Platform Fees**: Configurable platform fees for market resolution (default 2.5%)
- **Reentrancy Protection**: Security measures against common smart contract attacks
- **Event Logging**: Comprehensive event emission for frontend integration -->

## 🏗 Project Structure

```
prediction-market-dapp/
├── contracts/
│   └── PredictionMarket.sol       # Main smart contract
├── scripts/
│   └── deploy.js                  # Deployment script
├── frontend/
│   └── index.html                 # Simple web interface
├── hardhat.config.js              # Hardhat configuration
├── package.json                   # Dependencies and scripts
├── .env.example                   # Environment variables template
└── README.md                      # This file
```

## 🔧 Prerequisites

- Node.js (v16 or later)
- npm or yarn
- MetaMask browser extension
- Access to an Ethereum testnet (Goerli, Sepolia, etc.)

## 📦 Installation

1. **Clone the repository**

   ```bash
   git clone <your-repo-url>
   cd prediction-market-dapp
   ```

2. **Install dependencies**

   ```bash
   npm install
   ```

3. **Create environment file**

   ```bash
   cp .env.example .env
   ```

4. **Configure environment variables**
   Edit `.env` file with your values:
   ```env
   INFURA_API_KEY=your_infura_project_id
   PRIVATE_KEY=your_wallet_private_key
   ETHERSCAN_API_KEY=your_etherscan_api_key
   ```

## ⚙️ Configuration

### Network Configuration

The project is configured to work with multiple networks:

- **Local Development**: Hardhat local network
- **Goerli Testnet**: Ethereum test network
- **Sepolia Testnet**: Ethereum test network

### Smart Contract Configuration

Key parameters in the smart contract:

- **Platform Fee**: 2.5% (250 basis points)
- **Minimum Resolution Time**: 1 hour from market creation
- **Maximum Outcomes**: 10 per market
- **Minimum Creation Fee**: 0.001 ETH

## 🚀 Local Development Setup

### Quick Start Guide for Team Members

#### Prerequisites Setup

1. **Install Node.js** (v16 or later) from [nodejs.org](https://nodejs.org/)
2. **Install MetaMask** browser extension from [metamask.io](https://metamask.io/)
3. **Install Python** (for frontend server) - usually comes with Node.js

#### Initial Setup (One-time)

1. **Clone and install dependencies**

   ```bash
   git clone <your-repo-url>
   cd prediction-market-dapp
   npm install
   ```

2. **Configure MetaMask for local development**

   - Open MetaMask → Networks → Add Network
   - **Network Name:** `Localhost 8545`
   - **RPC URL:** `http://127.0.0.1:8545`
   - **Chain ID:** `31337`
   - **Currency Symbol:** `ETH`
   - Save the network

3. **Import test account to MetaMask**
   - Click MetaMask account avatar → Import Account
   - **Private Key:** `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
   - This gives you 10,000 ETH for testing

#### Starting the Development Environment

**Terminal 1: Start Blockchain**

```bash
npm run node
```

_Keep this running - shows blockchain activity_

**Terminal 2: Deploy Smart Contract**

```bash
npm run deploy:localhost
```

_Copy the contract address from output_

**Terminal 3: Start Frontend Server**

```bash
cd frontend
python -m http.server 8080
```

**Browser: Open Application**

1. Go to `http://localhost:8080`
2. Switch MetaMask to "Localhost 8545" network
3. Click "Connect Wallet"
4. You should see your balance (~10,000 ETH)

#### Stopping Everything

1. Press `Ctrl+C` in all three terminals
2. MetaMask will automatically disconnect

#### Troubleshooting

- **"MetaMask not detected"**: Ensure you're using `http://localhost:8080`, not opening HTML file directly
- **"Wrong network"**: Switch MetaMask to "Localhost 8545"
- **"No test ETH"**: Import the test account with the private key above
- **Contract errors**: Make sure you deployed with `npm run deploy:localhost`

#### Test Account Details

- **Address:** `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- **Private Key:** `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
- **Balance:** 10,000 ETH
- **Use for:** Creating markets (use different account as arbitrator)

#### For Creating Markets

- **Arbitrator Address:** Use `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` (Account #1)
- **Creation Fee:** Minimum 0.001 ETH
- **Resolution Time:** Must be at least 1 hour in the future

### Post-Deployment Steps

1. **Update frontend contract address**

   - Copy the deployed contract address from deployment output
   - Update `CONTRACT_ADDRESS` in `frontend/index.html`

2. **Add contract ABI to frontend**
   - Copy the ABI from `artifacts/contracts/PredictionMarket.sol/PredictionMarket.json`
   - Update `CONTRACT_ABI` in `frontend/index.html`

## 📱 Usage

### Creating a Market

1. Connect your MetaMask wallet
2. Navigate to "Create Market" tab
3. Fill in market details:
   - Description of the event to predict
   - Possible outcomes (2-10 options)
   - Resolution date and time
   - Arbitrator address (who will resolve the market)
   - Creation fee (minimum 0.001 ETH)
4. Submit transaction

### Placing Bets

1. Browse active markets in "Browse Markets" tab
2. Select an outcome by clicking on it
3. Enter bet amount in ETH
4. Click "Place Bet" and confirm transaction

### Resolving Markets

1. Only designated arbitrators can resolve markets
2. Markets can only be resolved after the resolution time
3. Arbitrator selects the winning outcome
4. All bets are then settled based on the result

### Withdrawing Winnings

1. After market resolution, winners can withdraw their share
2. Winnings are calculated proportionally based on bet amounts
3. Platform fee (2.5%) is deducted from winnings
4. Go to resolved market and click "Withdraw Winnings"

## 📜 Smart Contract Functions

### Public Functions

| Function                    | Description                         | Access            |
| --------------------------- | ----------------------------------- | ----------------- |
| `createMarket()`            | Create a new prediction market      | Anyone (with fee) |
| `placeBet()`                | Place a bet on market outcome       | Anyone            |
| `resolveMarket()`           | Resolve market with winning outcome | Arbitrator only   |
| `withdrawWinnings()`        | Withdraw winnings after resolution  | Winners only      |
| `getMarketInfo()`           | Get complete market information     | Anyone            |
| `getOutcomeProbabilities()` | Get current market probabilities    | Anyone            |

### View Functions

| Function                  | Description                                |
| ------------------------- | ------------------------------------------ |
| `getAllActiveMarkets()`   | Get IDs of all active markets              |
| `getAllResolvedMarkets()` | Get IDs of all resolved markets            |
| `getUserBets()`           | Get all bets placed by a user              |
| `getUserBetAmount()`      | Get user's bet amount for specific outcome |

## 🖥 Frontend Features

### Modern UI/UX

- **Responsive Design**: Works on desktop and mobile devices
- **Dark Theme**: Modern gradient design with glassmorphism effects
- **Real-time Updates**: Live probability calculations and bet tracking
- **Wallet Integration**: Seamless MetaMask connection

### Market Display

- **Market Cards**: Clean, organized display of market information
- **Probability Bars**: Visual representation of outcome probabilities
- **Status Indicators**: Clear indication of market status (active/resolved/expired)
- **Time Display**: Human-readable creation and resolution times

### User Experience

- **Tabbed Interface**: Easy navigation between browse, create, and personal bets
- **Form Validation**: Client-side validation for all inputs
- **Error Handling**: Clear error messages and success notifications
- **Transaction Tracking**: Real-time transaction status updates

## 🔐 Security Features

### Smart Contract Security

- **ReentrancyGuard**: Protection against reentrancy attacks
- **Access Control**: Role-based permissions using OpenZeppelin
- **Input Validation**: Comprehensive validation of all parameters
- **Safe Math**: Using Solidity 0.8+ built-in overflow protection

### Frontend Security

- **Input Sanitization**: All user inputs are validated
- **Wallet Integration**: Secure interaction with MetaMask
- **Error Boundaries**: Graceful handling of blockchain errors

## 🚧 Future Enhancements

- **Reputation System**: Track user prediction accuracy over time
- **Market Categories**: Organize markets by topics (sports, politics, etc.)
- **Social Features**: Market comments and discussion threads
- **Mobile App**: Native mobile application for iOS and Android
- **Advanced Analytics**: Detailed market statistics and user insights

## 🤝 Contributing

This project is developed for academic purposes as part of the SC4053/CE4153/CZ4153 Blockchain Technology course at NTU.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📚 References

- [Ethereum Documentation](https://ethereum.org/developers/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Hardhat Documentation](https://hardhat.org/docs/)
- [Prediction Market Research](https://en.wikipedia.org/wiki/Prediction_market)
- [Augur Protocol](https://www.augur.net/)
- [Course GitHub Repository](https://github.com/BlockchainCourseNTU/resource/)

---
