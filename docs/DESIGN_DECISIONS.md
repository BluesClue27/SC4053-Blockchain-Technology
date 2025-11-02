# Design Decisions: Multi-Arbitrator Prediction Market

## Table of Contents
- [Overview](#overview)
- [Core Design Decision: Multi-Arbitrator System](#core-design-decision-multi-arbitrator-system)
- [Byzantine Fault Tolerance](#byzantine-fault-tolerance)
- [Draw Handling Mechanism](#draw-handling-mechanism)
- [Fee Distribution Model](#fee-distribution-model)
- [Security Considerations](#security-considerations)
- [Gas Optimization Strategies](#gas-optimization-strategies)
- [Alternative Approaches Considered](#alternative-approaches-considered)

## Overview

This document explains the key design decisions made in implementing the PredictionMarket smart contract, with special emphasis on **why we chose a multi-arbitrator system** over single-arbitrator or fully automated alternatives.

## Core Design Decision: Multi-Arbitrator System

### The Problem: Trust & Centralization in Prediction Markets

Traditional prediction markets face a critical challenge: **Who decides the outcome?**

#### ❌ Problems with Single-Arbitrator Systems:

1. **Single Point of Failure**
   - One person controls the entire market resolution
   - If arbitrator is malicious, biased, or compromised → entire market fails
   - No recourse for users if arbitrator makes wrong decision

2. **Corruption Risk**
   - With large bet amounts, arbitrator has incentive to be bribed
   - Example: Market with 1000 ETH in bets, arbitrator could be paid 100 ETH to vote incorrectly
   - No way to detect or prevent this

3. **Lack of Accountability**
   - Single arbitrator's decision is final
   - No consensus mechanism
   - Users must blindly trust one person

4. **Availability Issues**
   - What if arbitrator loses private keys?
   - What if arbitrator goes offline or refuses to participate?
   - Market could be stuck unresolved forever

### ✅ Our Solution: Multi-Arbitrator Voting (3-21 Arbitrators)

We require **3 to 21 arbitrators** with **simple majority voting** (>50%) for resolution.

#### Why 3 Minimum?

```
SCENARIO: Bitcoin price prediction market with 100 ETH in bets

Single Arbitrator (❌):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Arbitrator A decides outcome
→ If A is bribed with 20 ETH, they manipulate the market
→ No protection mechanism
→ All bettors lose


3 Arbitrators (✓):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Require 2/3 majority (67%)

Attempt to bribe:
• Bribe 1 arbitrator: Cost 20 ETH → Still need 2 votes → FAILS
• Bribe 2 arbitrators: Cost 40 ETH → Gets majority → Success but costly

Result:
✓ 2x more expensive to manipulate
✓ Harder to coordinate collusion
✓ More likely someone acts honestly


5 Arbitrators (✓✓):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Require 3/5 majority (60%)

Attempt to bribe:
• Bribe 2 arbitrators: Cost 40 ETH → Still need 3 votes → FAILS
• Bribe 3 arbitrators: Cost 60 ETH → Gets majority → Success but very costly

Result:
✓ 3x more expensive to manipulate
✓ Much harder to coordinate collusion
✓ High probability someone acts honestly
```

**Mathematical Security:**
- **3 arbitrators**: Need to corrupt 2 (67%) → 2x cost multiplier
- **5 arbitrators**: Need to corrupt 3 (60%) → 3x cost multiplier
- **7 arbitrators**: Need to corrupt 4 (57%) → 4x cost multiplier

As arbitrator count increases, cost of attack increases linearly while coordination difficulty increases exponentially.

#### Why 21 Maximum?

We cap at 21 arbitrators to balance security with practicality:

**Gas Costs:**
- Each arbitrator vote = 1 transaction
- Checking eligibility loops through all arbitrators
- More arbitrators = higher gas costs for everyone

**Coordination Difficulty:**
- Finding 21 trusted, available arbitrators is challenging
- Synchronizing 21 people to vote is slow
- Diminishing returns after ~7-9 arbitrators

**Practical Example:**
```
Gas cost comparison (estimated):

3 arbitrators:
- Eligibility check: ~30,000 gas
- Vote processing: ~45,000 gas per vote
- Total: ~165,000 gas

21 arbitrators:
- Eligibility check: ~210,000 gas
- Vote processing: ~45,000 gas per vote
- Total: ~1,155,000 gas

Result: 7x more expensive but only marginally more secure than 7-9 arbitrators
```

### Why Simple Majority (50% + 1)?

We chose simple majority over supermajority (66%, 75%) for these reasons:

1. **Faster Resolution**
   - 3 arbitrators: Need 2 votes (can resolve after 2 votes)
   - vs. requiring all 3 votes = slower

2. **Byzantine Fault Tolerance**
   - Tolerates up to floor((n-1)/2) malicious/offline arbitrators
   - 5 arbitrators can handle 2 being compromised/offline

3. **Incentive Alignment**
   - If >50% vote wrong, system has bigger problems
   - Simpler threshold = clearer incentives

## Byzantine Fault Tolerance

Our system implements Byzantine fault tolerance through:

### 1. Majority Consensus

**Byzantine Generals Problem:** How do distributed parties agree when some may be malicious?

**Our Solution:**
```
Honest arbitrators: H
Malicious arbitrators: M
Total: n = H + M

Our guarantee: Market resolves correctly if H > M

Examples:
• 3 arbitrators: Tolerates 1 malicious (2 honest > 1 malicious)
• 5 arbitrators: Tolerates 2 malicious (3 honest > 2 malicious)
• 7 arbitrators: Tolerates 3 malicious (4 honest > 3 malicious)
```

### 2. Economic Incentives

**Honest Voting Incentivized:**
- Only correct voters get fees
- Incorrect voters get nothing
- Non-voters get nothing

**Example:**
```
5 arbitrators, 100 ETH market (1 ETH in arb fees)

Scenario A: All vote honestly
  • All 5 eligible for fees
  • Each gets 0.2 ETH

Scenario B: 2 vote dishonestly
  • Only 3 honest voters get fees
  • Each honest voter gets 0.33 ETH
  • 2 dishonest voters get 0 ETH

Incentive: Vote honestly to earn fees
```

### 3. Sybil Resistance

**Problem:** What if one person controls multiple arbitrator accounts?

**Our Protection:**
- Market creators choose arbitrators (social verification)
- Creators typically choose known, trusted individuals
- Duplicate addresses blocked at creation
- Economic cost: Need to bribe multiple distinct parties

**Limitation:** We don't prevent Sybil attacks at protocol level (would require identity verification, which breaks decentralization). We rely on market creators to choose diverse, independent arbitrators.

## Draw Handling Mechanism

### Why Allow Draws?

**Scenario: Contentious Outcome**
```
Market: "Did Candidate A win the election by >5%?"
Reality: Candidate A won by 4.9%

4 arbitrators vote:
• 2 say "No" (technically correct, <5%)
• 2 say "Yes" (margin of error, ~5%)

Result: 2-2 tie → No majority → DRAW

Instead of forcing one side to lose unfairly, we:
✓ Refund all bets (minus fees)
✓ Reward all arbitrators who participated
✓ Fair outcome when truth is ambiguous
```

### Draw Detection Logic

```solidity
// After all arbitrators vote:
if (maxVotes < requiredVotes) {
    // No outcome reached majority
    isDraw = true;
    // Refund all bets, fees go to all voters
}
```

**Examples:**

| Arbitrators | Required | Votes Distribution | Result |
|-------------|----------|-------------------|---------|
| 3 | 2 | 1-1-1 (all different) | DRAW |
| 4 | 3 | 2-2 (tie) | DRAW |
| 5 | 3 | 2-2-1 (no majority) | DRAW |
| 5 | 3 | 3-2 (majority) | WINNER |
| 7 | 4 | 3-2-2 (no majority) | DRAW |

### Draw vs Normal Resolution Fee Distribution

**Normal Resolution:**
- Only arbitrators who voted **correctly** get fees
- Incentivizes accurate voting
- Punishes incorrect votes

**Draw Resolution:**
- **All** arbitrators who voted get fees
- Rationale: No "correct" answer exists
- Rewards participation in ambiguous scenarios
- Prevents punishment for unpredictable outcomes

**Example:**
```
100 ETH market, 1 ETH in arbitrator fees

Normal Win (3 voted Yes, 2 voted No):
• Yes voters: 1 ETH / 3 = 0.33 ETH each
• No voters: 0 ETH
• Non-voters: 0 ETH

Draw (2 voted Yes, 2 voted No, 1 didn't vote):
• All 4 voters: 1 ETH / 4 = 0.25 ETH each
• Non-voter: 0 ETH

Key: Participation always rewarded in draws
```

## Fee Distribution Model

### Fee Structure

```
Total Fees: 2.5%
├── Platform Fee: 1.5% → Contract owner
└── Arbitrator Fee: 1.0% → Split among eligible arbitrators

Why this split?
• Platform needs revenue for maintenance
• Arbitrators need compensation for work
• 2.5% total is competitive with centralized markets
• Low enough to not discourage betting
```

### Fee Calculation Timing

**Design Decision: Calculate fees at resolution time, not during withdrawals**

**Why?**

❌ **Calculate during each withdrawal:**
```solidity
// Would need to do this for EVERY withdrawal:
function withdrawWinnings() {
    uint256 arbFee = (winnings * arbitratorFee) / 10000;
    // Store this somewhere...how?
    // What if withdrawal fails? Fees already deducted?
}
```
Issues:
- Complex accounting
- Gas inefficient (recalculate every time)
- Timing issues (what if market still has unclaimed winnings?)

✓ **Calculate once at resolution:**
```solidity
// Do this ONCE when market resolves:
function voteOnOutcome() {
    if (resolved) {
        uint256 totalArbFees = (totalBets * arbitratorFee) / 10000;
        market.collectedArbitratorFees = totalArbFees;
    }
}
```
Benefits:
- Calculate once, use many times
- Clear, deterministic fee pool
- Gas efficient
- No accounting complexity

### Proportional Payout Formula

**Question:** How much should a winner receive?

**Our Formula:**
```
userWinnings = (userBet / winningPool) * totalPool * (1 - fees)
```

**Example:**
```
Total pool: 100 ETH
├── "Yes" pool: 40 ETH (you bet 10 ETH here)
└── "No" pool: 60 ETH

"Yes" wins!

Your share: 10 / 40 = 25% of winning pool
Your gross winnings: 25% * 100 ETH = 25 ETH
Fees (2.5%): 0.625 ETH
Your net payout: 24.375 ETH

ROI: (24.375 - 10) / 10 = 143.75% return 🎉
```

**Why proportional vs fixed odds?**

❌ Fixed odds (like traditional betting):
- Requires setting odds at market creation
- Odds don't update as bets come in
- Doesn't reflect true market sentiment

✓ Proportional payout:
- Odds automatically adjust with each bet
- Reflects real-time market consensus
- More aligned with prediction market theory
- Dynamic pricing like Augur/Polymarket

## Security Considerations

### 1. Reentrancy Protection

**Attack Vector:**
```solidity
// Malicious contract could try:
contract Attacker {
    function attack() {
        predictionMarket.withdrawWinnings(marketId);
    }

    receive() external payable {
        // Called when receiving ETH
        predictionMarket.withdrawWinnings(marketId); // Try to withdraw again!
    }
}
```

**Our Protection:**
```solidity
function withdrawWinnings() nonReentrant {
    // 1. Checks
    require(!hasWithdrawn[msg.sender], "Already withdrawn");

    // 2. Effects - UPDATE STATE FIRST
    hasWithdrawn[msg.sender] = true;

    // 3. Interactions - EXTERNAL CALLS LAST
    payable(msg.sender).transfer(payout);
}
```

**Why it works:**
- State updated BEFORE external call
- If attacker tries to reenter, hasWithdrawn is already true
- Second call reverts at require() check
- nonReentrant modifier provides extra protection

### 2. Conflict of Interest Prevention

**Problems we prevent:**

1. **Creator betting on own market:**
   ```solidity
   require(msg.sender != market.creator, "Market creator cannot bet");
   ```
   Why? Creator controls resolution time, could manipulate timing

2. **Arbitrators betting:**
   ```solidity
   for (uint256 i = 0; i < market.arbitrators.length; i++) {
       require(msg.sender != market.arbitrators[i], "Arbitrator cannot bet");
   }
   ```
   Why? Arbitrators control outcome, direct conflict of interest

3. **Creator as arbitrator:**
   ```solidity
   require(_arbitrators[i] != msg.sender, "Creator cannot be arbitrator");
   ```
   Why? Would have total control over market outcome

### 3. Input Validation

**Every external function validates:**

```solidity
createMarket():
✓ Description not empty
✓ 2-10 outcomes
✓ Resolution time > now + 1 minute
✓ 3-21 arbitrators
✓ No duplicate arbitrators
✓ Minimum creation fee

placeBet():
✓ Market exists
✓ Not yet resolved
✓ Before resolution time
✓ Valid outcome index
✓ Bet amount > 0
✓ Not creator or arbitrator

voteOnOutcome():
✓ Market exists
✓ Is arbitrator
✓ After resolution time
✓ Haven't voted yet
✓ Valid outcome index
```

## Gas Optimization Strategies

### 1. Early Resolution

**Instead of waiting for all votes:**
```solidity
if (outcomeVotes[_outcome] >= requiredVotes) {
    // Resolve immediately when majority reached
    market.resolved = true;
    // Remaining arbitrators don't need to vote
}
```

**Example:**
```
7 arbitrators, need 4 for majority

Arb 1: Votes "Yes" (1/4)
Arb 2: Votes "Yes" (2/4)
Arb 3: Votes "Yes" (3/4)
Arb 4: Votes "Yes" (4/4) → RESOLVED!

Arbs 5, 6, 7 don't need to vote → Save 3 transactions worth of gas
```

### 2. Basis Points for Fees

**Why use basis points (out of 10,000) instead of decimals?**

❌ Using decimals (float):
```solidity
// Solidity doesn't support floats!
uint256 fee = winnings * 0.025; // DOESN'T WORK
```

❌ Using percentages (lossy):
```solidity
uint256 fee = (winnings * 25) / 1000;  // 2.5%
// Problem: Can't represent 1.5% accurately (would be 15/1000 = 1.5% but loses precision)
```

✓ Using basis points:
```solidity
uint256 platformFee = 150;    // 1.5% = 150 basis points
uint256 arbFee = 100;         // 1.0% = 100 basis points
uint256 fee = (winnings * (platformFee + arbFee)) / 10000;
// 1 basis point = 0.01%, so 250 bp = 2.5%
// Precise, no decimals needed
```

### 3. Storage Optimization

**Use storage efficiently:**
```solidity
// ✓ GOOD: Store once at resolution
market.collectedArbitratorFees = totalArbFees;

// ❌ BAD: Recalculate every time
// Would waste gas on repeated calculations
```

## Alternative Approaches Considered

### 1. Automated Oracle Resolution

**Approach:** Use Chainlink or other oracles to automatically resolve markets

**Pros:**
- Fully automated
- No human intervention needed
- Fast resolution

**Cons:**
- Only works for objective, on-chain data (prices, weather, etc.)
- Can't handle subjective questions ("Was the movie good?")
- Oracle manipulation risk
- Additional costs (LINK fees)
- Centralization (trusting oracle provider)

**Why we didn't choose it:**
- Prediction markets often involve subjective judgments
- Wanted fully decentralized solution
- Multi-arbitrator provides human judgment when needed

### 2. Token-Curated Registry (TCR) for Arbitrators

**Approach:** Stake tokens to become arbitrator, lose stake if vote incorrectly

**Pros:**
- Economic stake ensures honesty
- Open participation
- Decentralized arbitrator selection

**Cons:**
- Complex mechanism
- Requires additional token
- High barrier to entry (need capital)
- Plutocracy (rich people control outcomes)

**Why we didn't choose it:**
- Too complex for MVP
- Wanted market creators to choose trusted arbitrators
- Social trust > economic stake for smaller markets

### 3. Futarchy (Market-Based Resolution)

**Approach:** Create meta-markets to decide market outcomes

**Pros:**
- Fully market-driven
- No arbitrators needed
- Elegant economic model

**Cons:**
- Extremely complex
- Requires deep liquidity
- Can lead to market manipulation
- Hard to understand for average user

**Why we didn't choose it:**
- Too experimental
- Requires significant liquidity
- Multi-arbitrator is simpler and more intuitive

### 4. Single Arbitrator with Appeals

**Approach:** One arbitrator decides, with appeal mechanism if disputed

**Pros:**
- Simple initial design
- Fast resolution (usually)
- Appeals handle edge cases

**Cons:**
- Still has single point of failure
- Appeal mechanism adds complexity
- Who handles appeals? (Same problem recursively)

**Why we didn't choose it:**
- Doesn't fundamentally solve trust problem
- Multi-arbitrator is cleaner solution
- Appeals add gas costs anyway

## Conclusion

The **multi-arbitrator system with simple majority voting** provides the best balance of:

✓ **Security** - Byzantine fault tolerance, no single point of failure
✓ **Decentralization** - No central authority, distributed trust
✓ **Fairness** - Draw handling when consensus fails
✓ **Incentives** - Economic rewards for honest voting
✓ **Simplicity** - Easy to understand and implement
✓ **Gas Efficiency** - Optimistic resolution, minimal storage

While more complex alternatives exist (oracles, TCRs, futarchy), the multi-arbitrator approach offers a pragmatic, secure, and decentralized solution that works for both objective and subjective prediction markets.
