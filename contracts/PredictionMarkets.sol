// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PredictionMarket is ReentrancyGuard, Ownable {

    enum Category {
        SPORTS,
        POLITICS,
        CRYPTO,
        WEATHER,
        ENTERTAINMENT,
        SCIENCE,
        BUSINESS,
        OTHER
    }

    // Market struct containing all market state
    struct Market {
        uint256 id;                         
        string description;                 
        string[] outcomes;                  
        uint256 resolutionTime;            
        address creator;                    
        address[] arbitrators;             
        bool resolved;                     
        uint256 winningOutcome;           
        uint256 totalBets;                 

        mapping(uint256 => uint256) outcomeTotals;

        mapping(address => mapping(uint256 => uint256)) userBets;

        mapping(address => bool) hasWithdrawn;

        uint256 createdAt;                 
        bool exists;                       
        Category category;                 
        bool isDraw;                       

        mapping(address => bool) hasVoted;

        mapping(address => uint256) arbitratorVote;

        mapping(uint256 => uint256) outcomeVotes;

        uint256 totalVotes;                
        uint256 requiredVotes;             

        uint256 collectedArbitratorFees;

        mapping(address => bool) arbitratorFeeClaimed;
    }
    
    // Return struct for getMarketInfo() -
    // cannot return Market struct directly due to mappings
    struct MarketInfo {
        uint256 id;
        string description;
        string[] outcomes;
        uint256 resolutionTime;
        address creator;
        address[] arbitrators;
        bool resolved;
        uint256 winningOutcome;
        uint256 totalBets;
        uint256[] outcomeTotals;
        uint256 createdAt;
        uint256 totalVotes;
        uint256 requiredVotes;
        bool isDraw;
        Category category;
    }

    // UserBet struct containing individual bet details
    struct UserBet {
        uint256 marketId;               
        uint256 outcome;               
        uint256 amount;               
        uint256 timestamp;             
    }

    mapping(uint256 => Market) public markets;

    mapping(address => uint256[]) public userMarkets;

    mapping(address => UserBet[]) public userBets;

    uint256 public nextMarketId = 1;

    /**
     * Fee configuration in basis points (1 bp = 0.01%)
     * Platform fee: 150 bp = 1.5% - goes to platform
     * Arbitrator fee: 100 bp = 1.0% - split among eligible arbitrators
     * Total fees: 250 bp = 2.5% deducted from total bet pool
     */
    uint256 public platformFee = 150;
    uint256 public arbitratorFee = 100;

    // Maximum number of outcomes per market
    uint256 public constant MAX_OUTCOMES = 10;

    // Minimum time between market creation and resolution (1 minute - for testing purposes)
    uint256 public constant MIN_RESOLUTION_TIME = 1 minutes;
    
    event MarketCreated(
        uint256 indexed marketId,
        address indexed creator,
        string description,
        uint256 resolutionTime
    );
    
    event BetPlaced(
        uint256 indexed marketId,
        address indexed user,
        uint256 indexed outcome,
        uint256 amount
    );
    
    event MarketResolved(
        uint256 indexed marketId,
        uint256 indexed winningOutcome,
        uint256 totalPayout
    );
    
    event Withdrawal(
        uint256 indexed marketId,
        address indexed user,
        uint256 amount
    );

    event ArbitratorVoted(
        uint256 indexed marketId,
        address indexed arbitrator,
        uint256 indexed outcome
    );

    event ArbitratorFeeClaimed(
        uint256 indexed marketId,
        address indexed arbitrator,
        uint256 amount
    );

    modifier validMarket(uint256 _marketId) {
        require(markets[_marketId].exists, "Market does not exist");
        _;
    }

    modifier marketNotResolved(uint256 _marketId) {
        require(!markets[_marketId].resolved, "Market already resolved");
        _;
    }

    modifier onlyArbitrator(uint256 _marketId) {
        Market storage market = markets[_marketId];
        bool isArbitrator = false;
        for (uint256 i = 0; i < market.arbitrators.length; i++) {
            if (msg.sender == market.arbitrators[i]) {
                isArbitrator = true;
                break;
            }
        }
        require(isArbitrator, "Only arbitrator can vote");
        _;
    }
    
    constructor() Ownable(msg.sender) {}

    // Function to create new prediction market
    function createMarket(
        string memory _description,
        string[] memory _outcomes,
        uint256 _resolutionTime,
        address[] memory _arbitrators,
        Category _category
    ) external payable returns (uint256) {
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_outcomes.length >= 2 && _outcomes.length <= MAX_OUTCOMES, "Invalid number of outcomes");
        require(_resolutionTime > block.timestamp + MIN_RESOLUTION_TIME, "Resolution time too soon");
        require(_arbitrators.length >= 3, "Minimum 3 arbitrators required");
        require(_arbitrators.length <= 21, "Maximum 21 arbitrators allowed");
        require(msg.value >= 0.001 ether, "Minimum creation fee required");

        // Validate all arbitrators are non-zero and unique
        for (uint256 i = 0; i < _arbitrators.length; i++) {
            require(_arbitrators[i] != address(0), "Invalid arbitrator address");
            require(_arbitrators[i] != msg.sender, "Creator cannot be arbitrator");
            // Check for duplicates
            for (uint256 j = i + 1; j < _arbitrators.length; j++) {
                require(_arbitrators[i] != _arbitrators[j], "Duplicate arbitrator addresses");
            }
        }

        uint256 marketId = nextMarketId++;
        Market storage newMarket = markets[marketId];

        newMarket.id = marketId;
        newMarket.description = _description;
        newMarket.outcomes = _outcomes;
        newMarket.resolutionTime = _resolutionTime;
        newMarket.creator = msg.sender;
        newMarket.arbitrators = _arbitrators;
        newMarket.resolved = false;
        newMarket.winningOutcome = 0;
        newMarket.totalBets = 0;
        newMarket.createdAt = block.timestamp;
        newMarket.exists = true;
        newMarket.category = _category;

        // Required votes = simple majority
        newMarket.requiredVotes = (_arbitrators.length / 2) + 1;

        userMarkets[msg.sender].push(marketId);

        emit MarketCreated(marketId, msg.sender, _description, _resolutionTime);

        return marketId;
    }
    
    // Function to place bets
    function placeBet(uint256 _marketId, uint256 _outcome)
        external
        payable
        validMarket(_marketId)
        marketNotResolved(_marketId)
        nonReentrant
    {
        Market storage market = markets[_marketId];
        require(block.timestamp < market.resolutionTime, "Betting period has ended");
        require(_outcome < market.outcomes.length, "Invalid outcome");
        require(msg.value > 0, "Bet amount must be greater than 0");
        require(msg.sender != market.creator, "Market creator cannot bet on their own market");

        // Check if sender is any of the arbitrators
        for (uint256 i = 0; i < market.arbitrators.length; i++) {
            require(msg.sender != market.arbitrators[i], "Arbitrator cannot bet on this market");
        }
        
        market.userBets[msg.sender][_outcome] += msg.value;
        market.outcomeTotals[_outcome] += msg.value;
        market.totalBets += msg.value;
        
        userBets[msg.sender].push(UserBet({
            marketId: _marketId,
            outcome: _outcome,
            amount: msg.value,
            timestamp: block.timestamp
        }));
        
        emit BetPlaced(_marketId, msg.sender, _outcome, msg.value);
    }
    
    // Function for arbitrators to vote on outcome
    function voteOnOutcome(uint256 _marketId, uint256 _outcome)
        external
        validMarket(_marketId)
        marketNotResolved(_marketId)
        onlyArbitrator(_marketId)
    {
        Market storage market = markets[_marketId];
        require(block.timestamp >= market.resolutionTime, "Market not yet resolvable");
        require(_outcome < market.outcomes.length, "Invalid outcome");
        require(!market.hasVoted[msg.sender], "Already voted");

        market.hasVoted[msg.sender] = true;
        market.arbitratorVote[msg.sender] = _outcome; 
        market.outcomeVotes[_outcome]++;
        market.totalVotes++;

        emit ArbitratorVoted(_marketId, msg.sender, _outcome);

        // Check if this vote creates a majority
        // If it does, resolve the market immediately
        if (market.outcomeVotes[_outcome] >= market.requiredVotes) {
            market.resolved = true;
            market.winningOutcome = _outcome;
            market.isDraw = false;

            // Calculate arbitrator fees immediately (1% of total bet pool)
            uint256 totalArbitratorFees = (market.totalBets * arbitratorFee) / 10000;
            market.collectedArbitratorFees = totalArbitratorFees;

            emit MarketResolved(_marketId, _outcome, market.outcomeTotals[_outcome]);
        } 
        
        else if (market.totalVotes == market.arbitrators.length) {
            _checkForDraw(_marketId);
        }
    }

    // Function to check for draw or normal resolution
    function _checkForDraw(uint256 _marketId) internal {
        Market storage market = markets[_marketId];

        // Find the outcome with the maximum votes
        uint256 maxVotes = 0;
        uint256 outcomeWithMaxVotes = 0;

        for (uint256 i = 0; i < market.outcomes.length; i++) {
            if (market.outcomeVotes[i] > maxVotes) {
                maxVotes = market.outcomeVotes[i];
                outcomeWithMaxVotes = i;
            }
        }

        // Draw condition: No single outcome reached majority threshold
        // majority = n/2 + 1
        if (maxVotes < market.requiredVotes) {
            market.resolved = true;
            market.isDraw = true;
            market.winningOutcome = 0; 

            // Calculate total arbitrator fees (1% of total bet pool)
            // Draw scenario: fees are split among ALL arbitrators who voted
            uint256 totalArbitratorFees = (market.totalBets * arbitratorFee) / 10000;
            market.collectedArbitratorFees = totalArbitratorFees;

            emit MarketResolved(_marketId, 0, 0);
        } else {
            // NORMAL RESOLUTION: One outcome reached majority threshold
            market.resolved = true;
            market.winningOutcome = outcomeWithMaxVotes;
            market.isDraw = false;

            // Calculate total arbitrator fees (1% of total bet pool)
            // Normal scenario: fees only go to arbitrators who voted for winning outcome
            uint256 totalArbitratorFees = (market.totalBets * arbitratorFee) / 10000;
            market.collectedArbitratorFees = totalArbitratorFees;

            emit MarketResolved(_marketId, outcomeWithMaxVotes, market.outcomeTotals[outcomeWithMaxVotes]);
        }
    }

    /**
     * Function to withdraw winnings or refunds after market resolution
     * 
     * TWO DISTINCT WITHDRAWAL SCENARIOS:
     *
     * 1. DRAW SCENARIO (market.isDraw == true):
     * User gets refunded ALL their bets across all outcomes
     * Fees (2.5%) are still deducted from refund
     * Refund = totalUserBets * (100% - 2.5%)
     *
     * 2. NORMAL WIN SCENARIO (market.isDraw == false):
     * Only users who bet on winning outcome can withdraw
     * Winnings are proportional to bet amount
     * Winnings = (userBet / winningPool) * totalPool * (100% - 2.5%)
     *
     * PROPORTIONAL PAYOUT EXAMPLE:
     * Total pool: 100 ETH
     * Winning outcome pool: 40 ETH
     * User bet on winner: 10 ETH
     * Gross winnings: (10 / 40) * 100 = 25 ETH
     * Fees (2.5%): 0.625 ETH
     * Net payout: 24.375 ETH
     *
     * SECURITY:
     * hasWithdrawn check prevents double withdrawals
     * nonReentrant prevents reentrancy attacks
     * Marked withdrawn BEFORE transfer (checks-effects-interactions pattern)
     */
    function withdrawWinnings(uint256 _marketId)
        external
        validMarket(_marketId)
        nonReentrant
    {
        Market storage market = markets[_marketId];
        require(market.resolved, "Market not yet resolved");
        require(!market.hasWithdrawn[msg.sender], "Already withdrawn");

        // Mark as withdrawn BEFORE transfer to prevent reentrancy
        market.hasWithdrawn[msg.sender] = true;

        // Draw Scenario: Refund all bets across all outcomes
        if (market.isDraw) {
            uint256 totalUserBets = 0;
            for (uint256 i = 0; i < market.outcomes.length; i++) {
                totalUserBets += market.userBets[msg.sender][i];
            }
            require(totalUserBets > 0, "No bets found");

            uint256 refund = (totalUserBets * (10000 - platformFee - arbitratorFee)) / 10000;

            uint256 drawPlatformCut = (totalUserBets * platformFee) / 10000;

            payable(msg.sender).transfer(refund);

            if (drawPlatformCut > 0) {
                payable(owner()).transfer(drawPlatformCut);
            }

            emit Withdrawal(_marketId, msg.sender, refund);
            return;
        }

        // Normal Scenario: Withdraw winnings for winning outcome
        uint256 userWinningBet = market.userBets[msg.sender][market.winningOutcome];
        require(userWinningBet > 0, "No winning bet found");

        uint256 winningPool = market.outcomeTotals[market.winningOutcome];
        uint256 totalPool = market.totalBets;

        uint256 winnings = (userWinningBet * totalPool) / winningPool;

        uint256 payout = (winnings * (10000 - platformFee - arbitratorFee)) / 10000;

        uint256 platformCut = (winnings * platformFee) / 10000;

        payable(msg.sender).transfer(payout);

        if (platformCut > 0) {
            payable(owner()).transfer(platformCut);
        }

        emit Withdrawal(_marketId, msg.sender, payout);
    }

    // Function for arbitrators to claim their fee share after market resolution
    function claimArbitratorFee(uint256 _marketId)
        external
        validMarket(_marketId)
        nonReentrant
    {
        Market storage market = markets[_marketId];
        require(market.resolved, "Market not yet resolved");
        require(!market.arbitratorFeeClaimed[msg.sender], "Fee already claimed");

        require(_isArbitrator(_marketId, msg.sender), "Not an arbitrator");
        require(_isEligibleForFee(_marketId, msg.sender), "Not eligible for fee - did not vote or voted incorrectly");

        uint256 eligibleCount = _countEligibleArbitrators(_marketId);
        require(eligibleCount > 0, "No eligible arbitrators");

        uint256 arbitratorShare = market.collectedArbitratorFees / eligibleCount;
        require(arbitratorShare > 0, "No fees to claim");

        market.arbitratorFeeClaimed[msg.sender] = true;

        payable(msg.sender).transfer(arbitratorShare);

        emit ArbitratorFeeClaimed(_marketId, msg.sender, arbitratorShare);
    }

    // Check if address is an arbitrator for the market
    function _isArbitrator(uint256 _marketId, address _address) internal view returns (bool) {
        Market storage market = markets[_marketId];
        for (uint256 i = 0; i < market.arbitrators.length; i++) {
            if (market.arbitrators[i] == _address) {
                return true;
            }
        }
        return false;
    }

    /**
     * Function to check if an arbitrator is eligible for fee share
     * 
     * DRAW SCENARIO:
     * ALL arbitrators who voted are eligible (regardless of what they voted for)
     * Rationale: No single outcome was "correct", so all participants deserve compensation
     * Example: 3 arbitrators vote (1-1-1 split) → all 3 eligible
     *
     * NORMAL RESOLUTION:
     * ONLY arbitrators who voted for the WINNING outcome are eligible
     * Rationale: Incentivizes honest/accurate voting
     * Example: 5 arbitrators, 3 vote "Yes" (winner), 2 vote "No" → only the 3 eligible
     *
     * NON-VOTERS:
     * Arbitrators who didn't vote get NOTHING in either scenario
     * Prevents free-riding and encourages participation
     */
    function _isEligibleForFee(uint256 _marketId, address _arbitrator) internal view returns (bool) {
        Market storage market = markets[_marketId];

        if (market.isDraw) {
            return market.hasVoted[_arbitrator];
        } 
        else {
            return market.hasVoted[_arbitrator] && market.arbitratorVote[_arbitrator] == market.winningOutcome;
        }
    }

    // Function to count eligible arbitrators for fee distribution
    function _countEligibleArbitrators(uint256 _marketId) internal view returns (uint256) {
        Market storage market = markets[_marketId];
        uint256 count = 0;

        for (uint256 i = 0; i < market.arbitrators.length; i++) {
            address arb = market.arbitrators[i];
            if (market.isDraw) {
                if (market.hasVoted[arb]) {
                    count++;
                }
            } else {
                if (market.hasVoted[arb] && market.arbitratorVote[arb] == market.winningOutcome) {
                    count++;
                }
            }
        }

        return count;
    }

    // View function to get Market Info
    function getMarketInfo(uint256 _marketId) 
        external 
        view 
        validMarket(_marketId) 
        returns (MarketInfo memory) 
    {
        Market storage market = markets[_marketId];
        
        uint256[] memory outcomeTotals = new uint256[](market.outcomes.length);
        for (uint256 i = 0; i < market.outcomes.length; i++) {
            outcomeTotals[i] = market.outcomeTotals[i];
        }
        
        return MarketInfo({
            id: market.id,
            description: market.description,
            outcomes: market.outcomes,
            resolutionTime: market.resolutionTime,
            creator: market.creator,
            arbitrators: market.arbitrators,
            resolved: market.resolved,
            winningOutcome: market.winningOutcome,
            totalBets: market.totalBets,
            outcomeTotals: outcomeTotals,
            createdAt: market.createdAt,
            totalVotes: market.totalVotes,
            requiredVotes: market.requiredVotes,
            isDraw: market.isDraw,
            category: market.category
        });
    }
    
    // View function to get user's bet amount on a specific outcome
    function getUserBetAmount(uint256 _marketId, address _user, uint256 _outcome) 
        external 
        view 
        validMarket(_marketId) 
        returns (uint256) 
    {
        return markets[_marketId].userBets[_user][_outcome];
    }
    
    // View function to get outcome probabilities based on current bets
    function getOutcomeProbabilities(uint256 _marketId) 
        external 
        view 
        validMarket(_marketId) 
        returns (uint256[] memory probabilities) 
    {
        Market storage market = markets[_marketId];
        probabilities = new uint256[](market.outcomes.length);
        
        if (market.totalBets == 0) {
            uint256 equalProb = 10000 / market.outcomes.length;
            for (uint256 i = 0; i < market.outcomes.length; i++) {
                probabilities[i] = equalProb;
            }
        } 
        else {
            for (uint256 i = 0; i < market.outcomes.length; i++) {
                probabilities[i] = (market.outcomeTotals[i] * 10000) / market.totalBets;
            }
        }
    }
    
    // View function to get all bets placed by a user
    function getUserBets(address _user) external view returns (UserBet[] memory) {
        return userBets[_user];
    }

    // View function to get all markets created by a user
    function getUserMarkets(address _user) external view returns (uint256[] memory) {
        return userMarkets[_user];
    }

    // View function to check if an arbitrator has voted
    function hasArbitratorVoted(uint256 _marketId, address _arbitrator)
        external
        view
        validMarket(_marketId)
        returns (bool)
    {
        return markets[_marketId].hasVoted[_arbitrator];
    }

    // View function to check if a user has withdrawn winnings/refund
    function hasUserWithdrawn(uint256 _marketId, address _user)
        external
        view
        validMarket(_marketId)
        returns (bool)
    {
        return markets[_marketId].hasWithdrawn[_user];
    }

    // View function to get arbitrator fee info
    function getArbitratorFeeInfo(uint256 _marketId, address _arbitrator)
        external
        view
        validMarket(_marketId)
        returns (
            bool isArbitrator,
            bool hasVoted,
            uint256 votedOutcome,
            bool isEligible,
            uint256 potentialShare,
            bool hasClaimed,
            uint256 totalCollectedFees,
            uint256 eligibleCount
        )
    {
        Market storage market = markets[_marketId];

        isArbitrator = _isArbitrator(_marketId, _arbitrator);
        hasVoted = market.hasVoted[_arbitrator];
        votedOutcome = hasVoted ? market.arbitratorVote[_arbitrator] : 0;
        isEligible = market.resolved && _isEligibleForFee(_marketId, _arbitrator);
        hasClaimed = market.arbitratorFeeClaimed[_arbitrator];
        totalCollectedFees = market.collectedArbitratorFees;
        eligibleCount = market.resolved ? _countEligibleArbitrators(_marketId) : 0;
        potentialShare = (isEligible && eligibleCount > 0) ? totalCollectedFees / eligibleCount : 0;
    }

    // View function to get detailed arbitrator vote info for a market
    function getArbitratorVoteDetails(uint256 _marketId)
        external
        view
        validMarket(_marketId)
        returns (
            address[] memory arbitrators,
            bool[] memory hasVoted,
            uint256[] memory votes,
            bool[] memory isEligible
        )
    {
        Market storage market = markets[_marketId];
        uint256 arbCount = market.arbitrators.length;

        arbitrators = new address[](arbCount);
        hasVoted = new bool[](arbCount);
        votes = new uint256[](arbCount);
        isEligible = new bool[](arbCount);

        for (uint256 i = 0; i < arbCount; i++) {
            address arb = market.arbitrators[i];
            arbitrators[i] = arb;
            hasVoted[i] = market.hasVoted[arb];
            votes[i] = hasVoted[i] ? market.arbitratorVote[arb] : 0;
            isEligible[i] = market.resolved && _isEligibleForFee(_marketId, arb);
        }
    }

    // View function to get all active markets 
    function getAllActiveMarkets() external view returns (uint256[] memory activeMarkets) {
        uint256 activeCount = 0;

        // Count active markets 
        for (uint256 i = 1; i < nextMarketId; i++) {
            if (markets[i].exists && !markets[i].resolved) {
                activeCount++;
            }
        }

        activeMarkets = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 1; i < nextMarketId; i++) {
            if (markets[i].exists && !markets[i].resolved) {
                activeMarkets[index] = i;
                index++;
            }
        }
    }
    
    // View function to get all resolved markets
    function getAllResolvedMarkets() external view returns (uint256[] memory resolvedMarkets) {
        uint256 resolvedCount = 0;
        
        // Count resolved markets
        for (uint256 i = 1; i < nextMarketId; i++) {
            if (markets[i].exists && markets[i].resolved) {
                resolvedCount++;
            }
        }

        resolvedMarkets = new uint256[](resolvedCount);
        uint256 index = 0;
        for (uint256 i = 1; i < nextMarketId; i++) {
            if (markets[i].exists && markets[i].resolved) {
                resolvedMarkets[index] = i;
                index++;
            }
        }
    }
    
    // Owner-only functions to adjust fees
    function setPlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 1000, "Fee cannot exceed 10%"); 
        platformFee = _newFee;
    }

    // Owner-only function to adjust arbitrator fee
    function setArbitratorFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 500, "Arbitrator fee cannot exceed 5%"); 
        arbitratorFee = _newFee;
    }

    // Emergency withdrawal function for owner to recover funds
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
    
    receive() external payable {}
}