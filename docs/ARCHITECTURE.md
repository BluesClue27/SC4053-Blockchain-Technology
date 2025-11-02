# Prediction Market Architecture

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          FRONTEND (Web3 dApp)                            │
│                                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                   │
│  │   Create     │  │    Browse    │  │   My Bets    │                   │
│  │   Markets    │  │   Markets    │  │    Page      │                   │
│  └──────────────┘  └──────────────┘  └──────────────┘                   │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │               MetaMask (Wallet Integration)                      │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Web3.js / Ethers.js
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    ETHEREUM BLOCKCHAIN (Localhost)                       │
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │              PredictionMarket Smart Contract                    │    │
│  │                                                                  │    │
│  │  ┌────────────────────────────────────────────────────────┐   │    │
│  │  │           CORE DATA STRUCTURES                          │   │    │
│  │  │                                                          │   │    │
│  │  │  Market {                                               │   │    │
│  │  │    - Basic Info (id, description, outcomes)            │   │    │
│  │  │    - Timing (resolutionTime, createdAt)                │   │    │
│  │  │    - Participants (creator, arbitrators)                │   │    │
│  │  │    - Betting State (totalBets, outcomeTotals)          │   │    │
│  │  │    - Voting State (votes, requiredVotes)               │   │    │
│  │  │    - Resolution (resolved, isDraw, winningOutcome)     │   │    │
│  │  │    - Fees (collectedArbitratorFees)                    │   │    │
│  │  │  }                                                       │   │    │
│  │  └────────────────────────────────────────────────────────┘   │    │
│  │                                                                  │    │
│  │  ┌────────────────────────────────────────────────────────┐   │    │
│  │  │              KEY FUNCTIONS                              │   │    │
│  │  │                                                          │   │    │
│  │  │  createMarket()   ──→  Store market data               │   │    │
│  │  │  placeBet()       ──→  Accept ETH, update pools        │   │    │
│  │  │  voteOnOutcome()  ──→  Arbitrators vote, auto-resolve  │   │    │
│  │  │  withdrawWinnings() ─→ Transfer winnings/refunds       │   │    │
│  │  │  claimArbitratorFee() → Transfer arbitrator share      │   │    │
│  │  └────────────────────────────────────────────────────────┘   │    │
│  └────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

## User Role Interactions

```
┌──────────────────────────────────────────────────────────────────┐
│                    MARKET CREATOR                                 │
│  1. Connects wallet                                               │
│  2. Fills market form (description, outcomes, resolution time)    │
│  3. Specifies 3-21 arbitrator addresses                          │
│  4. Pays creation fee (≥0.001 ETH)                               │
│  5. Submits transaction                                           │
│                                                                    │
│  ┌─────────────────────┐                                         │
│  │  Smart Contract     │                                         │
│  │  ───────────────    │                                         │
│  │  • Validates inputs │                                         │
│  │  • Prevents creator │                                         │
│  │    from being       │                                         │
│  │    arbitrator       │                                         │
│  │  • Checks for       │                                         │
│  │    duplicate        │                                         │
│  │    arbitrators      │                                         │
│  │  • Calculates       │                                         │
│  │    requiredVotes    │                                         │
│  │    (n/2 + 1)        │                                         │
│  │  • Emits            │                                         │
│  │    MarketCreated    │                                         │
│  └─────────────────────┘                                         │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                       BETTOR                                      │
│  1. Browses active markets                                        │
│  2. Views current probabilities (based on bet distribution)       │
│  3. Selects an outcome                                            │
│  4. Enters bet amount                                             │
│  5. Submits transaction with ETH                                  │
│                                                                    │
│  ┌─────────────────────┐                                         │
│  │  Smart Contract     │                                         │
│  │  ───────────────    │                                         │
│  │  • Checks market    │                                         │
│  │    is active        │                                         │
│  │  • Prevents creator │                                         │
│  │    & arbitrators    │                                         │
│  │    from betting     │                                         │
│  │  • Updates          │                                         │
│  │    outcomeTotals    │                                         │
│  │  • Records user bet │                                         │
│  │  • Emits BetPlaced  │                                         │
│  └─────────────────────┘                                         │
│                                                                    │
│  AFTER RESOLUTION:                                                │
│  6. Checks if won or draw                                         │
│  7. Calls withdrawWinnings()                                      │
│  8. Receives proportional payout or refund (minus 2.5% fees)      │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                     ARBITRATOR                                    │
│  AFTER RESOLUTION TIME:                                           │
│  1. Views expired markets they're assigned to                     │
│  2. Selects the correct outcome                                   │
│  3. Calls voteOnOutcome()                                         │
│                                                                    │
│  ┌─────────────────────┐                                         │
│  │  Smart Contract     │                                         │
│  │  ───────────────    │                                         │
│  │  • Verifies caller  │                                         │
│  │    is arbitrator    │                                         │
│  │  • Prevents double  │                                         │
│  │    voting           │                                         │
│  │  • Records vote     │                                         │
│  │  • Checks if        │                                         │
│  │    majority reached │                                         │
│  │                     │                                         │
│  │  IF MAJORITY:       │                                         │
│  │  ✓ Resolve market   │                                         │
│  │  ✓ Set winner       │                                         │
│  │                     │                                         │
│  │  IF ALL VOTED BUT   │                                         │
│  │  NO MAJORITY:       │                                         │
│  │  ✓ Call             │                                         │
│  │    _checkForDraw()  │                                         │
│  │  ✓ Refund all bets  │                                         │
│  └─────────────────────┘                                         │
│                                                                    │
│  AFTER RESOLUTION:                                                │
│  4. Calls claimArbitratorFee()                                    │
│  5. Receives share of 1% arbitrator fees                          │
│     (if voted correctly or if draw and voted)                     │
└──────────────────────────────────────────────────────────────────┘
```

## Market Lifecycle Flow

```
┌─────────────┐
│   CREATED   │  ← createMarket() called
└──────┬──────┘
       │
       │  Users can placeBet()
       │  Probabilities update in real-time
       │
       ▼
┌─────────────┐
│   ACTIVE    │  ← Before resolutionTime
└──────┬──────┘
       │
       │  resolutionTime reached
       │  Betting closes
       │
       ▼
┌─────────────┐
│   EXPIRED   │  ← Arbitrators can vote
└──────┬──────┘
       │
       │  voteOnOutcome() called
       │
       ├──────────────────┬──────────────────┐
       │                  │                  │
       ▼                  ▼                  ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  MAJORITY   │    │  ALL VOTED  │    │  WAITING    │
│  REACHED    │    │ NO MAJORITY │    │ MORE VOTES  │
└──────┬──────┘    └──────┬──────┘    └──────┬──────┘
       │                  │                  │
       │                  │                  │
       ▼                  ▼                  └─► Continue voting
┌─────────────┐    ┌─────────────┐
│  RESOLVED   │    │    DRAW     │
│  (Winner)   │    │  (Refunds)  │
└──────┬──────┘    └──────┬──────┘
       │                  │
       │                  │
       └────────┬─────────┘
                │
                ▼
         ┌──────────────┐
         │  FINALIZED   │  ← withdrawWinnings() + claimArbitratorFee()
         └──────────────┘
```

## Voting Resolution Logic

```
SCENARIO 1: OPTIMISTIC RESOLUTION (Majority Reached Early)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Example: 5 arbitrators, requiredVotes = 3

Vote 1: Arb A votes "Yes"    → outcomeVotes["Yes"] = 1
Vote 2: Arb B votes "Yes"    → outcomeVotes["Yes"] = 2
Vote 3: Arb C votes "Yes"    → outcomeVotes["Yes"] = 3 ✓ MAJORITY!
                                Market resolves immediately
                                Arbs D & E don't need to vote

Result: WINNER = "Yes" (resolved early, gas efficient)


SCENARIO 2: DRAW (All Vote, No Majority)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Example: 4 arbitrators, requiredVotes = 3

Vote 1: Arb A votes "Yes"    → outcomeVotes["Yes"] = 1
Vote 2: Arb B votes "Yes"    → outcomeVotes["Yes"] = 2
Vote 3: Arb C votes "No"     → outcomeVotes["No"] = 1
Vote 4: Arb D votes "No"     → outcomeVotes["No"] = 2
                                totalVotes = 4 (all voted)
                                maxVotes = 2 < requiredVotes (3)
                                _checkForDraw() called

Result: DRAW (all bets refunded minus fees)


SCENARIO 3: LATE RESOLUTION (All Vote, Winner Found)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Example: 5 arbitrators, requiredVotes = 3

Vote 1: Arb A votes "Yes"    → outcomeVotes["Yes"] = 1
Vote 2: Arb B votes "No"     → outcomeVotes["No"] = 1
Vote 3: Arb C votes "Yes"    → outcomeVotes["Yes"] = 2
Vote 4: Arb D votes "Maybe"  → outcomeVotes["Maybe"] = 1
Vote 5: Arb E votes "Yes"    → outcomeVotes["Yes"] = 3
                                totalVotes = 5 (all voted)
                                maxVotes = 3 >= requiredVotes (3)
                                _checkForDraw() finds winner

Result: WINNER = "Yes" (resolved after all votes)
```

## Fee Distribution Examples

```
NORMAL RESOLUTION FEE FLOW
══════════════════════════════════════════════════════════════

Market: 100 ETH total bets
Fees: 2.5% total (1.5% platform + 1% arbitrator)

User A bet 10 ETH on winner:
  ┌─────────────────────────┐
  │ Gross winnings: 25 ETH  │  (10/40 * 100 = 25)
  ├─────────────────────────┤
  │ Platform fee: 0.375 ETH │  (25 * 1.5% = 0.375)
  │ Arb fee: 0.25 ETH       │  (25 * 1% = 0.25)
  ├─────────────────────────┤
  │ Net payout: 24.375 ETH  │  ✓ Sent to User A
  └─────────────────────────┘

3 arbitrators voted correctly (out of 5 total):
  ┌─────────────────────────┐
  │ Total arb fees: 1 ETH   │  (100 * 1% = 1)
  ├─────────────────────────┤
  │ Eligible: 3 arbitrators │
  │ Per arbitrator: 0.33 ETH│  (1 / 3 = 0.33)
  └─────────────────────────┘
  ✓ Arbs A, B, C get 0.33 ETH each
  ✗ Arbs D, E voted wrong → get nothing


DRAW SCENARIO FEE FLOW
══════════════════════════════════════════════════════════════

Market: 100 ETH total bets
Votes: 2-2 tie → DRAW

User A bet 10 ETH total (any outcomes):
  ┌─────────────────────────┐
  │ Total bets: 10 ETH      │
  ├─────────────────────────┤
  │ Platform fee: 0.15 ETH  │  (10 * 1.5% = 0.15)
  │ Arb fee: 0.1 ETH        │  (10 * 1% = 0.1)
  ├─────────────────────────┤
  │ Refund: 9.75 ETH        │  ✓ Sent to User A
  └─────────────────────────┘

4 arbitrators voted (all eligible in draw):
  ┌─────────────────────────┐
  │ Total arb fees: 1 ETH   │  (100 * 1% = 1)
  ├─────────────────────────┤
  │ Eligible: 4 arbitrators │  (all who voted)
  │ Per arbitrator: 0.25 ETH│  (1 / 4 = 0.25)
  └─────────────────────────┘
  ✓ All 4 voting arbs get 0.25 ETH each
```

## Security Mechanisms

```
┌──────────────────────────────────────────────────────────┐
│         CONFLICT OF INTEREST PREVENTION                   │
├──────────────────────────────────────────────────────────┤
│  ✗ Market creators CANNOT bet on their own markets       │
│  ✗ Arbitrators CANNOT bet on markets they judge          │
│  ✗ Market creators CANNOT be arbitrators                 │
│                                                            │
│  → Prevents insider manipulation and bias                 │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│         REENTRANCY PROTECTION                             │
├──────────────────────────────────────────────────────────┤
│  ✓ nonReentrant modifier on all withdrawal functions     │
│  ✓ Checks-Effects-Interactions pattern                   │
│  ✓ State updated BEFORE external transfers               │
│                                                            │
│  Example:                                                  │
│    market.hasWithdrawn[user] = true;  ← State change     │
│    payable(user).transfer(amount);     ← External call   │
│                                                            │
│  → Prevents reentrancy attacks during ETH transfers       │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│         DOUBLE-WITHDRAWAL PROTECTION                      │
├──────────────────────────────────────────────────────────┤
│  ✓ hasWithdrawn mapping tracks who already claimed       │
│  ✓ arbitratorFeeClaimed tracks arbitrator fee claims     │
│                                                            │
│  → Prevents users from claiming winnings multiple times   │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│         BYZANTINE FAULT TOLERANCE                         │
├──────────────────────────────────────────────────────────┤
│  ✓ Requires 3-21 arbitrators (no single point of failure)│
│  ✓ Simple majority voting (>50%)                         │
│  ✓ Draw handling when consensus fails                    │
│                                                            │
│  Scenarios:                                                │
│  • 1 malicious arb out of 3: Still need 2/3 majority    │
│  • 2 colluding arbs out of 5: Still need 3/5 majority   │
│  • Perfect tie: Fair refund to all bettors               │
│                                                            │
│  → Prevents single arbitrator manipulation                │
└──────────────────────────────────────────────────────────┘
```
