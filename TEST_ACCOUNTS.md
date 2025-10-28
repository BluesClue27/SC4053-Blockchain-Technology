# Test Accounts for Local Development

This document contains pre-funded test accounts provided by Hardhat for local development and testing. All accounts have **10,000 ETH** on the local blockchain.

## How to Use These Accounts

1. Open MetaMask
2. Click the account avatar (top right)
3. Select "Import Account"
4. Choose "Private Key" as the import method
5. Paste the private key from the list below
6. Repeat for as many accounts as you need

## Important Notes

- **Arbitrators:** You need to select at least **3 accounts** to act as arbitrators when creating a market
- **Bidders:** You can use any accounts (including arbitrators) to place bets on markets
- **Market Creator:** Any account can create a market (requires 0.001 ETH creation fee)
- All accounts are reset when you restart the local blockchain (`npm run node`)

## Available Test Accounts

### Account #0
```
Address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
Balance: 10,000 ETH
```

### Account #1
```
Address: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
Private Key: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
Balance: 10,000 ETH
```

### Account #2
```
Address: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
Private Key: 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
Balance: 10,000 ETH
```

### Account #3
```
Address: 0x90F79bf6EB2c4f870365E785982E1f101E93b906
Private Key: 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6
Balance: 10,000 ETH
```

### Account #4
```
Address: 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
Private Key: 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a
Balance: 10,000 ETH
```

### Account #5
```
Address: 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc
Private Key: 0x701b615bbdfb9de65240bc28bd21bbc0d996645a3dd57e7b12bc2bdf6f192c82
Balance: 10,000 ETH
```

### Account #6
```
Address: 0x976EA74026E726554dB657fA54763abd0C3a0aa9
Private Key: 0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba
Balance: 10,000 ETH
```

### Account #7
```
Address: 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955
Private Key: 0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e
Balance: 10,000 ETH
```

### Account #8
```
Address: 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f
Private Key: 0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356
Balance: 10,000 ETH
```

### Account #9
```
Address: 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720
Private Key: 0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97
Balance: 10,000 ETH
```

## Recommended Testing Setup

### Scenario 1: Basic Testing
- **Market Creator:** Account #0
- **Arbitrators (3 required):** Accounts #1, #2, #3
- **Bidders:** Accounts #4, #5, #6

### Scenario 2: Multiple Markets
- **Market Creator 1:** Account #0
- **Market Creator 2:** Account #1
- **Arbitrators (3 required):** Accounts #7, #8, #9
- **Bidders:** Accounts #2, #3, #4, #5, #6

### Scenario 3: Complex Testing
- **Market Creators:** Accounts #0, #1, #2
- **Arbitrators (3 required):** Accounts #3, #4, #5
- **Bidders:** Accounts #6, #7, #8, #9

## Testing Workflow Example

1. **Import Accounts:**
   - Import at least 4 accounts (1 creator + 3 arbitrators minimum)
   - Optionally import more accounts for bidders

2. **Create a Market:**
   - Switch to Account #0 in MetaMask
   - Go to "Create Market" tab
   - Fill in market details
   - Add at least 3 arbitrator addresses (e.g., Accounts #1, #2, #3)
   - Pay 0.001 ETH creation fee
   - Submit transaction

3. **Place Bets:**
   - Switch to different accounts in MetaMask (e.g., Accounts #4, #5, #6)
   - Browse to the market you created
   - Place bets on different outcomes
   - Each account can bet different amounts

4. **Resolve Market:**
   - Wait until after the resolution time
   - Switch to one of the arbitrator accounts (e.g., Account #1)
   - The arbitrators will vote on the winning outcome
   - Once consensus is reached, the market resolves

5. **Withdraw Winnings:**
   - Switch to an account that bet on the winning outcome
   - Click "Withdraw Winnings" button
   - Receive your proportional share of the pot (minus 2.5% platform fee)

## Security Notes

**⚠️ IMPORTANT - FOR LOCAL TESTING ONLY**

- These private keys are publicly known and should **NEVER** be used on mainnet or public testnets
- These accounts are only for local Hardhat development
- Do not send real ETH or tokens to these addresses
- Anyone with access to these private keys can control these accounts

## Troubleshooting

### "Nonce too high" error
When you restart the local blockchain, MetaMask's transaction history becomes outdated:
1. Open MetaMask → Settings → Advanced
2. Click "Clear activity tab data" or "Reset Account"
3. This resets the nonce for all accounts

### Account balance shows 0 ETH
Make sure:
1. The local blockchain is running (`npm run node`)
2. MetaMask is connected to "Localhost 8545" network (Chain ID: 31337)
3. You've imported the account using the correct private key

### Cannot import account
If you see "This account has already been imported":
- You've already imported this account
- Check your MetaMask account list
- Switch between accounts using the account dropdown

## Additional Resources

- [Hardhat Network Documentation](https://hardhat.org/hardhat-network/docs)
- [MetaMask User Guide](https://metamask.io/faqs/)
- [Project README](./README.md)
