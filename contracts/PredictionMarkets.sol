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
        bool isDraw;                        // True if market ended in a tie
        // Voting mechanism
        mapping(address => bool) hasVoted;
        mapping(address => uint256) arbitratorVote; // arbitrator => outcome they voted for
        mapping(uint256 => uint256) outcomeVotes;  // outcome => vote count
        uint256 totalVotes;
        uint256 requiredVotes;              // Minimum votes needed for majority
        // Fee tracking
        uint256 collectedArbitratorFees;    // Total arbitrator fees collected
        mapping(address => bool) arbitratorFeeClaimed; // Track if arbitrator claimed their fee
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
        bool isDraw;
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
    uint256 public platformFee = 150; // 1.5% (out of 10000)
    uint256 public arbitratorFee = 100; // 1.0% (out of 10000) - split among all arbitrators
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

        // Calculate required votes: Simple majority (more than half)
        // For 3 arbitrators: required=2 (2/3 = 67%)
        // For 4 arbitrators: required=3 (3/4 = 75%)
        // For 5 arbitrators: required=3 (3/5 = 60%)
        // For 7 arbitrators: required=4 (4/7 = 57%)
        newMarket.requiredVotes = (_arbitrators.length / 2) + 1; // Simple majority

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
        market.arbitratorVote[msg.sender] = _outcome; // Record what they voted for
        market.outcomeVotes[_outcome]++;
        market.totalVotes++;

        emit ArbitratorVoted(_marketId, msg.sender, _outcome);

        // Check if we have enough votes to resolve
        if (market.outcomeVotes[_outcome] >= market.requiredVotes) {
            market.resolved = true;
            market.winningOutcome = _outcome;
            market.isDraw = false;
            emit MarketResolved(_marketId, _outcome, market.outcomeTotals[_outcome]);
        } else if (market.totalVotes == market.arbitrators.length) {
            // All arbitrators have voted, check for draw
            _checkForDraw(_marketId);
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
        market.arbitratorVote[msg.sender] = _winningOutcome; // Record what they voted for
        market.outcomeVotes[_winningOutcome]++;
        market.totalVotes++;

        emit ArbitratorVoted(_marketId, msg.sender, _winningOutcome);

        // Check if we have enough votes to resolve
        if (market.outcomeVotes[_winningOutcome] >= market.requiredVotes) {
            market.resolved = true;
            market.winningOutcome = _winningOutcome;
            market.isDraw = false;
            emit MarketResolved(_marketId, _winningOutcome, market.outcomeTotals[_winningOutcome]);
        } else if (market.totalVotes == market.arbitrators.length) {
            // All arbitrators have voted, check for draw
            _checkForDraw(_marketId);
        }
    }

    function _checkForDraw(uint256 _marketId) internal {
        Market storage market = markets[_marketId];

        // Find the maximum votes any outcome received
        uint256 maxVotes = 0;
        uint256 outcomeWithMaxVotes = 0;
        uint256 outcomesWithMaxVotes = 0;

        for (uint256 i = 0; i < market.outcomes.length; i++) {
            if (market.outcomeVotes[i] > maxVotes) {
                maxVotes = market.outcomeVotes[i];
                outcomeWithMaxVotes = i;
                outcomesWithMaxVotes = 1;
            } else if (market.outcomeVotes[i] == maxVotes && maxVotes > 0) {
                outcomesWithMaxVotes++;
            }
        }

        // If multiple outcomes have the same max votes, it's a draw
        if (outcomesWithMaxVotes > 1) {
            market.resolved = true;
            market.isDraw = true;
            market.winningOutcome = 0; // Doesn't matter for draws
            emit MarketResolved(_marketId, 0, 0); // 0 indicates draw
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

        market.hasWithdrawn[msg.sender] = true;

        // Handle draw scenario - refund all bets minus fees
        if (market.isDraw) {
            uint256 totalUserBets = 0;
            for (uint256 i = 0; i < market.outcomes.length; i++) {
                totalUserBets += market.userBets[msg.sender][i];
            }
            require(totalUserBets > 0, "No bets found");

            // Deduct fees from refund
            uint256 refund = (totalUserBets * (10000 - platformFee - arbitratorFee)) / 10000;

            // Collect fees
            uint256 platformCut = (totalUserBets * platformFee) / 10000;
            uint256 arbitratorCut = (totalUserBets * arbitratorFee) / 10000;

            market.collectedArbitratorFees += arbitratorCut;

            payable(msg.sender).transfer(refund);
            if (platformCut > 0) {
                payable(owner()).transfer(platformCut);
            }

            emit Withdrawal(_marketId, msg.sender, refund);
            return;
        }

        // Normal resolution - pay winners
        uint256 userWinningBet = market.userBets[msg.sender][market.winningOutcome];
        require(userWinningBet > 0, "No winning bet found");

        uint256 winningPool = market.outcomeTotals[market.winningOutcome];
        uint256 totalPool = market.totalBets;

        // Calculate proportional winnings
        uint256 winnings = (userWinningBet * totalPool) / winningPool;

        // Deduct platform and arbitrator fees
        uint256 payout = (winnings * (10000 - platformFee - arbitratorFee)) / 10000;

        // Collect fees
        uint256 platformCut = (winnings * platformFee) / 10000;
        uint256 arbitratorCut = (winnings * arbitratorFee) / 10000;

        market.collectedArbitratorFees += arbitratorCut;

        payable(msg.sender).transfer(payout);
        if (platformCut > 0) {
            payable(owner()).transfer(platformCut);
        }

        emit Withdrawal(_marketId, msg.sender, payout);
    }

    function claimArbitratorFee(uint256 _marketId)
        external
        validMarket(_marketId)
        nonReentrant
    {
        Market storage market = markets[_marketId];
        require(market.resolved, "Market not yet resolved");
        require(!market.arbitratorFeeClaimed[msg.sender], "Fee already claimed");

        // Check if sender is an arbitrator
        bool isArbitrator = false;
        for (uint256 i = 0; i < market.arbitrators.length; i++) {
            if (market.arbitrators[i] == msg.sender) {
                isArbitrator = true;
                break;
            }
        }
        require(isArbitrator, "Not an arbitrator");

        // Check eligibility based on market outcome
        bool eligible = false;

        if (market.isDraw) {
            // For draws, all arbitrators who voted get paid
            eligible = market.hasVoted[msg.sender];
        } else {
            // For normal resolution, only those who voted for winning outcome get paid
            eligible = market.hasVoted[msg.sender] && market.arbitratorVote[msg.sender] == market.winningOutcome;
        }

        require(eligible, "Not eligible for fee - did not vote or voted incorrectly");

        // Calculate how many arbitrators are eligible
        uint256 eligibleCount = 0;
        for (uint256 i = 0; i < market.arbitrators.length; i++) {
            address arb = market.arbitrators[i];
            if (market.isDraw) {
                if (market.hasVoted[arb]) {
                    eligibleCount++;
                }
            } else {
                if (market.hasVoted[arb] && market.arbitratorVote[arb] == market.winningOutcome) {
                    eligibleCount++;
                }
            }
        }

        require(eligibleCount > 0, "No eligible arbitrators");

        // Calculate arbitrator's share
        uint256 arbitratorShare = market.collectedArbitratorFees / eligibleCount;
        require(arbitratorShare > 0, "No fees to claim");

        market.arbitratorFeeClaimed[msg.sender] = true;

        payable(msg.sender).transfer(arbitratorShare);

        emit ArbitratorFeeClaimed(_marketId, msg.sender, arbitratorShare);
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
            requiredVotes: market.requiredVotes,
            isDraw: market.isDraw
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

    function hasArbitratorVoted(uint256 _marketId, address _arbitrator)
        external
        view
        validMarket(_marketId)
        returns (bool)
    {
        return markets[_marketId].hasVoted[_arbitrator];
    }

    function hasUserWithdrawn(uint256 _marketId, address _user)
        external
        view
        validMarket(_marketId)
        returns (bool)
    {
        return markets[_marketId].hasWithdrawn[_user];
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

    function setArbitratorFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 500, "Arbitrator fee cannot exceed 5%"); // Max 5%
        arbitratorFee = _newFee;
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
    
    receive() external payable {}
}