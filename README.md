# 🔮 Prediction Market DApp

A decentralized prediction market platform built on Ethereum that allows users to create markets, place bets on future events, and earn rewards for correct predictions.

## 📋 Table of Contents

- [Quick Start](#-quick-start)
- [First-Time Setup Guide](#-first-time-setup-guide)
- [Features](#features)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
- [Troubleshooting](#-troubleshooting)
- [Usage](#usage)
- [Smart Contract Functions](#smart-contract-functions)
- [Frontend Features](#frontend-features)
- [Security Features](#security-features)

## 🏃 Quick Start

1. **Install prerequisites:** Node.js v16+ and MetaMask browser extension
2. **Clone and install:**
   ```bash
   git clone https://github.com/your-username/SC4053-Blockchain-Technology.git
   cd SC4053-Blockchain-Technology
   npm install
   ```
3. **Configure MetaMask:** Add network with RPC `http://127.0.0.1:8545`, Chain ID `31337`
4. **Import test accounts:** Import at least 4 accounts (1 main + 3 arbitrators) - See [TEST_ACCOUNTS.md](./TEST_ACCOUNTS.md) for all 20 available accounts
5. **Start blockchain (Terminal 1):** `npm run node`
6. **Deploy contract (Terminal 2):** `npm run deploy:localhost`
7. **Start frontend (Terminal 3):** `cd frontend && python -m http.server 8080`
8. **Open browser:** Navigate to `http://localhost:8080`, switch MetaMask to "Localhost 8545", and connect wallet

See [First-Time Setup Guide](#-first-time-setup-guide) below for detailed step-by-step instructions.

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
│   ├── index.html                 # Main web interface
│   ├── css/
│   │   └── styles.css             # Application styles
│   └── js/
│       └── app.js                 # Frontend JavaScript logic
├── artifacts/                      # Compiled contract artifacts
├── cache/                          # Hardhat cache
├── hardhat.config.js              # Hardhat configuration
├── package.json                   # Dependencies and scripts
├── deployment.json                # Deployed contract addresses
├── TEST_ACCOUNTS.md               # Test account addresses and private keys (20 accounts)
└── README.md                      # This file
```

## 🚀 First-Time Setup Guide

### Step 1: Prerequisites Installation

Before running this project, ensure you have the following installed:

1. **Node.js (v16 or later)**
   - Download from [nodejs.org](https://nodejs.org/)
   - Verify installation: `node --version`

2. **MetaMask Browser Extension**
   - Install from [metamask.io](https://metamask.io/)
   - Available for Chrome, Firefox, Brave, and Edge

3. **Python (for frontend server)**
   - Usually comes with Node.js
   - Verify installation: `python --version` or `python3 --version`
   - Alternative: Use Node.js http-server (`npm install -g http-server`)

### Step 2: Project Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/SC4053-Blockchain-Technology.git
   cd SC4053-Blockchain-Technology
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```
   This will install Hardhat, OpenZeppelin contracts, and all required packages.

### Step 3: MetaMask Configuration

Configure MetaMask to connect to the local Hardhat network:

1. Open MetaMask extension
2. Click the network dropdown at the top
3. Select "Add Network" or "Add a network manually"
4. Enter the following details:
   - **Network Name:** `Localhost 8545`
   - **RPC URL:** `http://127.0.0.1:8545`
   - **Chain ID:** `31337`
   - **Currency Symbol:** `ETH`
5. Click "Save"

### Step 4: Import Test Accounts

Hardhat provides 20 pre-funded test accounts (each with 10,000 ETH). You need to import multiple accounts for testing.

**IMPORTANT:** You need at least **4 accounts** total:
- 1 account for creating markets and placing bets
- 3 accounts to act as arbitrators (minimum required)

**Quick Import - First Account:**

1. In MetaMask, click the account avatar (top right)
2. Select "Import Account"
3. Select "Private Key" as import method
4. **Paste this private key:** `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
5. Click "Import"

This gives you **Account #0** (`0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`) with 10,000 ETH.

**Import Additional Accounts:**

For a complete list of all 20 available test accounts with their addresses and private keys, see **[TEST_ACCOUNTS.md](./TEST_ACCOUNTS.md)**.

That document includes:
- All 20 test account addresses and private keys
- 4 recommended testing scenarios (basic, multiple markets, complex, and large-scale)
- Step-by-step workflow examples
- Instructions for using accounts as arbitrators or bidders

**Minimum Requirement:** Import at least 3 more accounts (for arbitrators). You can import more if you want to test with multiple bidders or complex scenarios.

### Step 5: Start the Local Environment

You need to open **THREE separate terminal windows**:

**Terminal 1 - Start Local Blockchain:**
```bash
npm run node
```
This starts a local Ethereum blockchain at `http://127.0.0.1:8545`. Keep this terminal running.

**Terminal 2 - Deploy Smart Contract:**
```bash
npm run deploy:localhost
```
This deploys the PredictionMarket contract to your local blockchain.

**IMPORTANT:** Copy the contract address from the output. It will look like:
```
PredictionMarket deployed to: 0x5FbDB2315678afecb367f032d93F642f64180aa3
```

**Terminal 3 - Start Frontend Server:**
```bash
cd frontend
python -m http.server 8080
```
Or if using Python 3 specifically:
```bash
cd frontend
python3 -m http.server 8080
```

Alternative using Node.js (if Python is not available):
```bash
npx http-server frontend -p 8080
```

### Step 6: Access the Application

1. Open your web browser
2. Navigate to `http://localhost:8080`
3. MetaMask should prompt you to connect
4. **Switch MetaMask network to "Localhost 8545"** (important!)
5. Click "Connect Wallet" button in the application
6. Approve the connection in MetaMask

You should now see:
- Your wallet address displayed
- Your balance (~10,000 ETH)
- Ability to create markets and place bets

### Step 7: Test the Application

#### Create Your First Market

1. Click on the "Create Market" tab
2. Fill in the form:
   - **Description:** "Will it rain tomorrow?"
   - **Outcomes:** Add two outcomes (e.g., "Yes", "No")
   - **Resolution Time:** Select a date/time at least 1 hour in the future
   - **Arbitrator Addresses:** Add at least 3 arbitrator addresses from the accounts you imported
     - Example: Use addresses from Accounts #1, #2, #3 (see [TEST_ACCOUNTS.md](./TEST_ACCOUNTS.md))
     - You can use any 3+ addresses from your imported accounts
   - **Creation Fee:** `0.001` ETH (minimum)
3. Click "Create Market"
4. Confirm the transaction in MetaMask

**Note:** See [TEST_ACCOUNTS.md](./TEST_ACCOUNTS.md) for recommended testing scenarios with specific account assignments.

#### Place a Bet

1. Go to "Browse Markets" tab
2. You should see your newly created market
3. Click on an outcome
4. Enter bet amount (e.g., `0.1` ETH)
5. Click "Place Bet"
6. Confirm transaction in MetaMask

### Stopping the Application

When you're done testing:

1. Press `Ctrl+C` in each of the three terminal windows
2. Close the browser tab
3. MetaMask will automatically disconnect

### Restarting After Shutdown

**IMPORTANT:** When you restart the local blockchain (`npm run node`), it creates a fresh blockchain state. You must:

1. Start the blockchain again (`npm run node`)
2. Deploy the contract again (`npm run deploy:localhost`)
3. Get the new contract address (it may be the same or different)
4. **Reset MetaMask account:**
   - Open MetaMask → Settings → Advanced
   - Click "Clear activity tab data" or "Reset Account"
   - This clears the transaction history for the new blockchain instance

## ⚙️ Configuration

### Network Configuration

The project supports multiple networks (configured in `hardhat.config.js`):

- **Local Development**: Hardhat network (Chain ID: 31337)
- **Localhost**: Local Hardhat node at `http://127.0.0.1:8545`
- **Goerli Testnet**: Ethereum test network (deprecated)
- **Sepolia Testnet**: Ethereum test network
- **Mumbai**: Polygon testnet
- **BSC Testnet**: Binance Smart Chain testnet

### Smart Contract Parameters

Key parameters in the PredictionMarket contract:

- **Platform Fee:** 2.5% (250 basis points)
- **Minimum Resolution Time:** 1 hour from market creation
- **Maximum Outcomes:** 10 per market
- **Minimum Creation Fee:** 0.001 ETH
- **Fee Recipient:** Contract deployer (can be changed)

### Environment Variables (Optional)

For deploying to public testnets (not required for local development):

Create a `.env` file in the project root:
```env
INFURA_API_KEY=your_infura_project_id
PRIVATE_KEY=your_wallet_private_key
ETHERSCAN_API_KEY=your_etherscan_api_key
POLYGONSCAN_API_KEY=your_polygonscan_api_key
BSCSCAN_API_KEY=your_bscscan_api_key
```

## 🔧 Troubleshooting

### Common Issues

1. **"MetaMask not detected"**
   - Make sure you're accessing via `http://localhost:8080`, not by opening the HTML file directly
   - Ensure MetaMask extension is installed and enabled

2. **"Wrong network" error**
   - Check that MetaMask is connected to "Localhost 8545" network
   - Verify the Chain ID is 31337

3. **"Nonce too high" or transaction errors**
   - Reset MetaMask account: Settings → Advanced → Reset Account
   - This happens when you restart the local blockchain

4. **"Contract not deployed" or undefined address**
   - Make sure you ran `npm run deploy:localhost` in Terminal 2
   - Verify the contract address is correct in `frontend/js/app.js`

5. **"Insufficient funds" error**
   - Ensure you imported the test account with 10,000 ETH
   - Check you're connected to the correct account in MetaMask

6. **Python server won't start**
   - Try `python3 -m http.server 8080` instead
   - Or use Node.js: `npx http-server frontend -p 8080`

7. **"Port 8545 already in use"**
   - Another process is using that port
   - Kill the process or restart your computer
   - On Windows: `netstat -ano | findstr :8545` then `taskkill /PID <process_id> /F`

8. **Contract address keeps changing**
   - This is normal when restarting the local blockchain
   - The contract address is deterministic based on deployment order
   - Usually stays the same if you deploy in the same sequence

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
