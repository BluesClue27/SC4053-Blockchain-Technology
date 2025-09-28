// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PredictionMarket is ReentrancyGuard, Ownable {
    
    struct Market {
        uint256 id;
        string description;
        string[] outcomes;
        uint256 resolutionTime;
        address creator;
        address arbitrator;
        bool resolved;
        uint256 winningOutcome;
        uint256 totalBets;
        mapping(uint256 => uint256) outcomeTotals; // outcome => total bet amount
        mapping(address => mapping(uint256 => uint256)) userBets; // user => outcome => amount
        mapping(address => bool) hasWithdrawn;
        uint256 createdAt;
        bool exists;
    }
    
    struct MarketInfo {
        uint256 id;
        string description;
        string[] outcomes;
        uint256 resolutionTime;
        address creator;
        address arbitrator;
        bool resolved;
        uint256 winningOutcome;
        uint256 totalBets;
        uint256[] outcomeTotals;
        uint256 createdAt;
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
    uint256 public constant MIN_RESOLUTION_TIME = 1 hours;
    
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
    
    modifier validMarket(uint256 _marketId) {
        require(markets[_marketId].exists, "Market does not exist");
        _;
    }
    
    modifier marketNotResolved(uint256 _marketId) {
        require(!markets[_marketId].resolved, "Market already resolved");
        _;
    }
    
    modifier onlyArbitrator(uint256 _marketId) {
        require(msg.sender == markets[_marketId].arbitrator, "Only arbitrator can resolve");
        _;
    }
    
    constructor() Ownable(msg.sender) {}
    
    function createMarket(
        string memory _description,
        string[] memory _outcomes,
        uint256 _resolutionTime,
        address _arbitrator
    ) external payable returns (uint256) {
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_outcomes.length >= 2 && _outcomes.length <= MAX_OUTCOMES, "Invalid number of outcomes");
        require(_resolutionTime > block.timestamp + MIN_RESOLUTION_TIME, "Resolution time too soon");
        require(_arbitrator != address(0), "Invalid arbitrator address");
        require(msg.value >= 0.001 ether, "Minimum creation fee required");
        
        uint256 marketId = nextMarketId++;
        Market storage newMarket = markets[marketId];
        
        newMarket.id = marketId;
        newMarket.description = _description;
        newMarket.outcomes = _outcomes;
        newMarket.resolutionTime = _resolutionTime;
        newMarket.creator = msg.sender;
        newMarket.arbitrator = _arbitrator;
        newMarket.resolved = false;
        newMarket.winningOutcome = 0;
        newMarket.totalBets = 0;
        newMarket.createdAt = block.timestamp;
        newMarket.exists = true;
        
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
    
    function resolveMarket(uint256 _marketId, uint256 _winningOutcome) 
        external 
        validMarket(_marketId) 
        marketNotResolved(_marketId)
        onlyArbitrator(_marketId)
    {
        Market storage market = markets[_marketId];
        require(block.timestamp >= market.resolutionTime, "Market not yet resolvable");
        require(_winningOutcome < market.outcomes.length, "Invalid winning outcome");
        
        market.resolved = true;
        market.winningOutcome = _winningOutcome;
        
        emit MarketResolved(_marketId, _winningOutcome, market.outcomeTotals[_winningOutcome]);
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
            arbitrator: market.arbitrator,
            resolved: market.resolved,
            winningOutcome: market.winningOutcome,
            totalBets: market.totalBets,
            outcomeTotals: outcomeTotals,
            createdAt: market.createdAt
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
        
        // Count active markets
        for (uint256 i = 1; i < nextMarketId; i++) {
            if (markets[i].exists && !markets[i].resolved && block.timestamp < markets[i].resolutionTime) {
                activeCount++;
            }
        }
        
        // Fill array
        activeMarkets = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 1; i < nextMarketId; i++) {
            if (markets[i].exists && !markets[i].resolved && block.timestamp < markets[i].resolutionTime) {
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