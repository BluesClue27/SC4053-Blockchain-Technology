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

    struct Market {
        uint256 id;
        string description;
        string[] outcomes;
        uint256 resolutionTime;
        address creator;
        address[] arbitrators;              // Multiple arbitrators
        bool resolved;
        uint256 winningOutcome;
        uint256 totalBets;
        mapping(uint256 => uint256) outcomeTotals; // outcome => total bet amount
        mapping(address => mapping(uint256 => uint256)) userBets; // user => outcome => amount
        mapping(address => bool) hasWithdrawn;
        uint256 createdAt;
        bool exists;
        Category category;                  // Market category
        // Voting mechanism
        mapping(address => bool) hasVoted;
        mapping(uint256 => uint256) outcomeVotes;  // outcome => vote count
        uint256 totalVotes;
        uint256 requiredVotes;              // Minimum votes needed (2f+1)
    }
    
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
    }
    
    struct UserBet {
        uint256 marketId;
        uint256 outcome;
        uint256 amount;
        uint256 timestamp;
    }
    
    mapping(uint256 => Market) public markets;
    mapping(address => uint256[]) public userMarkets; // markets created by user
    mapping(address => UserBet[]) public userBets; // all bets by user
    
    uint256 public nextMarketId = 1;
    uint256 public platformFee = 250; // 2.5% (out of 10000)
    uint256 public constant MAX_OUTCOMES = 10;
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
    
    function createMarket(
        string memory _description,
        string[] memory _outcomes,
        uint256 _resolutionTime,
        address[] memory _arbitrators
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

        // Calculate required votes: 2f+1 where f = (n-1)/3
        // For 3 arbitrators: f=0, required=1 (just 1 vote but we'll use majority)
        // For 4 arbitrators: f=1, required=3 (67%)
        // For 7 arbitrators: f=2, required=5 (71%)
        newMarket.requiredVotes = (_arbitrators.length * 2) / 3 + 1; // Simple majority + 1

        userMarkets[msg.sender].push(marketId);

        emit MarketCreated(marketId, msg.sender, _description, _resolutionTime);

        return marketId;
    }
    
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

        // Record the vote
        market.hasVoted[msg.sender] = true;
        market.outcomeVotes[_outcome]++;
        market.totalVotes++;

        emit ArbitratorVoted(_marketId, msg.sender, _outcome);

        // Check if we have enough votes to resolve
        if (market.outcomeVotes[_outcome] >= market.requiredVotes) {
            market.resolved = true;
            market.winningOutcome = _outcome;
            emit MarketResolved(_marketId, _outcome, market.outcomeTotals[_outcome]);
        }
    }

    // Legacy function name for backwards compatibility - calls voteOnOutcome
    function resolveMarket(uint256 _marketId, uint256 _winningOutcome)
        external
        validMarket(_marketId)
        marketNotResolved(_marketId)
        onlyArbitrator(_marketId)
    {
        Market storage market = markets[_marketId];
        require(block.timestamp >= market.resolutionTime, "Market not yet resolvable");
        require(_winningOutcome < market.outcomes.length, "Invalid outcome");
        require(!market.hasVoted[msg.sender], "Already voted");

        // Record the vote
        market.hasVoted[msg.sender] = true;
        market.outcomeVotes[_winningOutcome]++;
        market.totalVotes++;

        emit ArbitratorVoted(_marketId, msg.sender, _winningOutcome);

        // Check if we have enough votes to resolve
        if (market.outcomeVotes[_winningOutcome] >= market.requiredVotes) {
            market.resolved = true;
            market.winningOutcome = _winningOutcome;
            emit MarketResolved(_marketId, _winningOutcome, market.outcomeTotals[_winningOutcome]);
        }
    }
    
    function withdrawWinnings(uint256 _marketId) 
        external 
        validMarket(_marketId) 
        nonReentrant 
    {
        Market storage market = markets[_marketId];
        require(market.resolved, "Market not yet resolved");
        require(!market.hasWithdrawn[msg.sender], "Already withdrawn");
        
        uint256 userWinningBet = market.userBets[msg.sender][market.winningOutcome];
        require(userWinningBet > 0, "No winning bet found");
        
        uint256 winningPool = market.outcomeTotals[market.winningOutcome];
        uint256 totalPool = market.totalBets;
        
        // Calculate proportional winnings
        uint256 winnings = (userWinningBet * totalPool) / winningPool;
        
        // Deduct platform fee
        uint256 fee = (winnings * platformFee) / 10000;
        uint256 payout = winnings - fee;
        
        market.hasWithdrawn[msg.sender] = true;
        
        payable(msg.sender).transfer(payout);
        if (fee > 0) {
            payable(owner()).transfer(fee);
        }
        
        emit Withdrawal(_marketId, msg.sender, payout);
    }
    
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
            requiredVotes: market.requiredVotes
        });
    }
    
    function getUserBetAmount(uint256 _marketId, address _user, uint256 _outcome) 
        external 
        view 
        validMarket(_marketId) 
        returns (uint256) 
    {
        return markets[_marketId].userBets[_user][_outcome];
    }
    
    function getOutcomeProbabilities(uint256 _marketId) 
        external 
        view 
        validMarket(_marketId) 
        returns (uint256[] memory probabilities) 
    {
        Market storage market = markets[_marketId];
        probabilities = new uint256[](market.outcomes.length);
        
        if (market.totalBets == 0) {
            // Equal probability if no bets
            uint256 equalProb = 10000 / market.outcomes.length;
            for (uint256 i = 0; i < market.outcomes.length; i++) {
                probabilities[i] = equalProb;
            }
        } else {
            for (uint256 i = 0; i < market.outcomes.length; i++) {
                probabilities[i] = (market.outcomeTotals[i] * 10000) / market.totalBets;
            }
        }
    }
    
    function getUserBets(address _user) external view returns (UserBet[] memory) {
        return userBets[_user];
    }
    
    function getUserMarkets(address _user) external view returns (uint256[] memory) {
        return userMarkets[_user];
    }
    
    function getAllActiveMarkets() external view returns (uint256[] memory activeMarkets) {
        uint256 activeCount = 0;

        // Count active markets (including those awaiting arbitrator votes)
        for (uint256 i = 1; i < nextMarketId; i++) {
            if (markets[i].exists && !markets[i].resolved) {
                activeCount++;
            }
        }

        // Fill array
        activeMarkets = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 1; i < nextMarketId; i++) {
            if (markets[i].exists && !markets[i].resolved) {
                activeMarkets[index] = i;
                index++;
            }
        }
    }
    
    function getAllResolvedMarkets() external view returns (uint256[] memory resolvedMarkets) {
        uint256 resolvedCount = 0;
        
        // Count resolved markets
        for (uint256 i = 1; i < nextMarketId; i++) {
            if (markets[i].exists && markets[i].resolved) {
                resolvedCount++;
            }
        }
        
        // Fill array
        resolvedMarkets = new uint256[](resolvedCount);
        uint256 index = 0;
        for (uint256 i = 1; i < nextMarketId; i++) {
            if (markets[i].exists && markets[i].resolved) {
                resolvedMarkets[index] = i;
                index++;
            }
        }
    }
    
    function setPlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 1000, "Fee cannot exceed 10%"); // Max 10%
        platformFee = _newFee;
    }
    
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
    
    receive() external payable {}
}