// Contract configuration
const CONTRACT_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3'; // Replace with deployed contract address
const CONTRACT_ABI = [
    // Add your contract ABI here
    "function createMarket(string memory _description, string[] memory _outcomes, uint256 _resolutionTime, address[] memory _arbitrators, uint8 _category) external payable returns (uint256)",
    "function placeBet(uint256 _marketId, uint256 _outcome) external payable",
    "function getMarketInfo(uint256 _marketId) external view returns (tuple(uint256 id, string description, string[] outcomes, uint256 resolutionTime, address creator, address[] arbitrators, bool resolved, uint256 winningOutcome, uint256 totalBets, uint256[] outcomeTotals, uint256 createdAt, uint256 totalVotes, uint256 requiredVotes, bool isDraw, uint8 category))",
    "function hasUserWithdrawn(uint256 _marketId, address _user) external view returns (bool)",
    "function claimArbitratorFee(uint256 _marketId) external",
    "function getAllActiveMarkets() external view returns (uint256[] memory)",
    "function getAllResolvedMarkets() external view returns (uint256[] memory)",
    "function getUserBets(address _user) external view returns (tuple(uint256 marketId, uint256 outcome, uint256 amount, uint256 timestamp)[] memory)",
    "function getOutcomeProbabilities(uint256 _marketId) external view returns (uint256[] memory)",
    "function getUserBetAmount(uint256 _marketId, address _user, uint256 _outcome) external view returns (uint256)",
    "function hasArbitratorVoted(uint256 _marketId, address _arbitrator) external view returns (bool)",
    "function withdrawWinnings(uint256 _marketId) external",
    "function voteOnOutcome(uint256 _marketId, uint256 _outcome) external",
    "function getArbitratorFeeInfo(uint256 _marketId, address _arbitrator) external view returns (bool isArbitrator, bool hasVoted, uint256 votedOutcome, bool isEligible, uint256 potentialShare, bool hasClaimed, uint256 totalCollectedFees, uint256 eligibleCount)",
    "function getArbitratorVoteDetails(uint256 _marketId) external view returns (address[] arbitrators, bool[] hasVoted, uint256[] votes, bool[] isEligible)"
];

let provider, signer, contract, userAddress;
let selectedOutcome = null;
let selectedMarketId = null;

// Category mapping
const CATEGORIES = {
    0: 'Sports',
    1: 'Politics',
    2: 'Crypto',
    3: 'Weather',
    4: 'Entertainment',
    5: 'Science',
    6: 'Business',
    7: 'Other'
};

// Global variables to store all markets for filtering
let allActiveMarkets = [];
let allResolvedMarkets = [];
let allMyBetsMarkets = [];

// Helper function to get category name
function getCategoryName(categoryId) {
    return CATEGORIES[categoryId] || 'Unknown';
}

// Helper function to get category badge HTML
function getCategoryBadge(categoryId) {
    const categoryName = getCategoryName(categoryId);
    const colors = {
        'Sports': '#4CAF50',
        'Politics': '#2196F3',
        'Crypto': '#FF9800',
        'Weather': '#00BCD4',
        'Entertainment': '#E91E63',
        'Science': '#9C27B0',
        'Business': '#607D8B',
        'Other': '#795548'
    };
    const color = colors[categoryName] || '#9E9E9E';
    return `<span style="display: inline-block; padding: 4px 12px; background: ${color}; color: white; border-radius: 12px; font-size: 12px; font-weight: 600; margin-left: 10px;">${categoryName}</span>`;
}

// Filter markets by category
function filterMarkets(section) {
    let filterId, containerId, markets;

    if (section === 'active') {
        filterId = 'activeMarketsFilter';
        containerId = 'activeMarkets';
        markets = allActiveMarkets;
    } else if (section === 'resolved') {
        filterId = 'resolvedMarketsFilter';
        containerId = 'resolvedMarkets';
        markets = allResolvedMarkets;
    } else if (section === 'my-bets') {
        filterId = 'myBetsFilter';
        containerId = 'myBets';
        markets = allMyBetsMarkets;
    }

    const selectedCategory = document.getElementById(filterId).value;
    const container = document.getElementById(containerId);

    // Filter markets by category
    const filteredMarkets = selectedCategory === ''
        ? markets
        : markets.filter(marketHTML => {
            // Extract category from the data attribute in the HTML
            const match = marketHTML.match(/data-category="(\d+)"/);
            return match && match[1] === selectedCategory;
        });

    // Display filtered markets
    if (filteredMarkets.length === 0) {
        container.innerHTML = '<p class="empty-message">No markets found in this category.</p>';
    } else {
        container.innerHTML = filteredMarkets.join('');
    }
}

// Initialize the app
window.addEventListener('load', async () => {
    setMinDateTime();
    if (typeof window.ethereum !== 'undefined') {
        console.log('MetaMask detected');
        // Check if already connected
        const accounts = await ethereum.request({ method: 'eth_accounts' });
        if (accounts.length > 0) {
            await connectWallet();
        }
    }
});

function setMinDateTime() {
    const now = new Date();
    now.setHours(now.getHours() + 1); // Minimum 1 hour from now
    const minDateTime = now.toISOString().slice(0, 16);
    document.getElementById('resolutionTime').min = minDateTime;
}

async function connectWallet() {
    try {
        if (typeof window.ethereum === 'undefined') {
            throw new Error('MetaMask not detected');
        }

        await ethereum.request({ method: 'eth_requestAccounts' });
        provider = new ethers.providers.Web3Provider(window.ethereum);
        signer = provider.getSigner();
        userAddress = await signer.getAddress();

        // Initialize contract
        contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);

        // Update UI
        document.getElementById('walletAddress').textContent = `${userAddress.slice(0, 6)}...${userAddress.slice(-4)}`;
        document.getElementById('connectBtn').textContent = 'Connected';
        document.getElementById('connectBtn').disabled = true;

        // Get balance
        const balance = await provider.getBalance(userAddress);
        document.getElementById('walletBalance').textContent = `(${ethers.utils.formatEther(balance).slice(0, 6)} ETH)`;

        // Load data
        await loadActiveMarkets();
        await loadResolvedMarkets();
        await loadMyBets();

        // Listen for account changes
        ethereum.on('accountsChanged', (accounts) => {
            if (accounts.length === 0) {
                location.reload();
            } else {
                location.reload();
            }
        });

    } catch (error) {
        showError(error);
    }
}

function switchTab(tabName) {
    // Update tab buttons
    document.querySelectorAll('.tab').forEach(tab => tab.classList.remove('active'));
    event.target.classList.add('active');

    // Update tab content
    document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
    document.getElementById(tabName + '-tab').classList.add('active');

    // Load data for the active tab
    if (tabName === 'markets' && contract) {
        loadActiveMarkets();
        loadResolvedMarkets();
    } else if (tabName === 'my-bets' && contract) {
        loadMyBets();
    }
}

function addOutcome() {
    const container = document.getElementById('outcomesContainer');
    const outcomeDiv = document.createElement('div');
    outcomeDiv.className = 'outcome-input';
    outcomeDiv.innerHTML = `
        <input type="text" placeholder="Outcome ${container.children.length + 1}" required>
        <button type="button" class="btn btn-danger btn-small" onclick="removeOutcome(this)">Remove</button>
    `;
    container.appendChild(outcomeDiv);
}

function removeOutcome(button) {
    const container = document.getElementById('outcomesContainer');
    if (container.children.length > 2) {
        button.parentElement.remove();
    } else {
        showError('You need at least 2 outcomes');
    }
}

async function createMarket(event) {
    event.preventDefault();

    if (!contract) {
        showError('Please connect your wallet first');
        return;
    }

    try {
        const description = document.getElementById('description').value;
        const resolutionTime = new Date(document.getElementById('resolutionTime').value).getTime() / 1000;
        const arbitratorsInput = document.getElementById('arbitrators').value;
        const creationFee = document.getElementById('creationFee').value;
        const category = parseInt(document.getElementById('category').value);

        // Parse arbitrators (comma-separated addresses)
        const arbitrators = arbitratorsInput
            .split(',')
            .map(addr => addr.trim())
            .filter(addr => addr.length > 0);

        if (arbitrators.length < 3) {
            showError('Please provide at least 3 arbitrator addresses (comma-separated)');
            return;
        }

        if (arbitrators.length > 21) {
            showError('Maximum 21 arbitrators allowed');
            return;
        }

        // Basic validation for Ethereum addresses
        for (const addr of arbitrators) {
            if (!addr.match(/^0x[a-fA-F0-9]{40}$/)) {
                showError(`Invalid Ethereum address: ${addr}`);
                return;
            }
        }

        // Get outcomes
        const outcomeInputs = document.querySelectorAll('#outcomesContainer input');
        const outcomes = Array.from(outcomeInputs).map(input => input.value.trim()).filter(val => val);

        if (outcomes.length < 2) {
            showError('Please provide at least 2 outcomes');
            return;
        }

        showSuccess('Creating market... Please confirm transaction in your wallet.');

        const tx = await contract.createMarket(
            description,
            outcomes,
            resolutionTime,
            arbitrators,
            category,
            { value: ethers.utils.parseEther(creationFee) }
        );

        showSuccess('Transaction submitted. Waiting for confirmation...');
        await tx.wait();

        showSuccess('Market created successfully!');

        // Reset form
        event.target.reset();
        document.getElementById('outcomesContainer').innerHTML = `
            <div class="outcome-input">
                <input type="text" placeholder="Outcome 1 (e.g., Yes)" required>
                <button type="button" class="btn btn-danger btn-small" onclick="removeOutcome(this)">Remove</button>
            </div>
            <div class="outcome-input">
                <input type="text" placeholder="Outcome 2 (e.g., No)" required>
                <button type="button" class="btn btn-danger btn-small" onclick="removeOutcome(this)">Remove</button>
            </div>
        `;

        // Refresh markets
        await loadActiveMarkets();

    } catch (error) {
        console.error("=== CREATE MARKET ERROR ===");
        console.error("Full error object:", error);
        console.error("Error message:", error.message);
        console.error("Error code:", error.code);
        if (error.data) {
            console.error("Error data:", error.data);
        }
        if (error.reason) {
            console.error("Error reason:", error.reason);
        }
        if (error.transaction) {
            console.error("Transaction:", error.transaction);
        }
        console.error("=== END ERROR ===");
        showError(error);
    }
}

async function loadActiveMarkets() {
    if (!contract) return;

    try {
        const marketIds = await contract.getAllActiveMarkets();
        const marketsContainer = document.getElementById('activeMarkets');

        if (marketIds.length === 0) {
            marketsContainer.innerHTML = `
                <div class="no-markets">
                    <h3>No active markets</h3>
                    <p>Be the first to create a prediction market!</p>
                </div>
            `;
            return;
        }

        const marketsHTML = await Promise.all(
            marketIds.map(async (id) => {
                const market = await contract.getMarketInfo(id);
                const probabilities = await contract.getOutcomeProbabilities(id);

                // Check if current user is an arbitrator who has already voted
                let arbitratorHasVoted = false;
                if (userAddress) {
                    const isArbitrator = market.arbitrators.some(
                        arb => arb.toLowerCase() === userAddress.toLowerCase()
                    );
                    if (isArbitrator) {
                        arbitratorHasVoted = await contract.hasArbitratorVoted(id, userAddress);
                    }
                }

                return renderMarketCard(market, probabilities, 'active', null, false, arbitratorHasVoted);
            })
        );

        // Store for filtering
        allActiveMarkets = marketsHTML;

        marketsContainer.innerHTML = marketsHTML.join('');

    } catch (error) {
        document.getElementById('activeMarkets').innerHTML = `<div class="error">Error loading markets: ${error.message}</div>`;
    }
}

async function loadResolvedMarkets() {
    if (!contract) return;

    try {
        const marketIds = await contract.getAllResolvedMarkets();
        const marketsContainer = document.getElementById('resolvedMarkets');

        if (marketIds.length === 0) {
            marketsContainer.innerHTML = `
                <div class="no-markets">
                    <h3>No resolved markets yet</h3>
                    <p>Resolved markets will appear here</p>
                </div>
            `;
            return;
        }

        const marketsHTML = await Promise.all(
            marketIds.map(async (id) => {
                const market = await contract.getMarketInfo(id);
                const probabilities = await contract.getOutcomeProbabilities(id);

                // Calculate user's winnings if they have any
                let userWinnings = null;
                let userHasLost = false;
                let userHasWithdrawn = false;
                let arbitratorFeeInfo = null;

                if (userAddress && market.resolved) {
                    if (market.isDraw) {
                        // Handle draw scenario - calculate total user bets for refund
                        let totalUserBets = 0;
                        for (let outcomeIndex = 0; outcomeIndex < market.outcomes.length; outcomeIndex++) {
                            const betAmount = await contract.getUserBetAmount(id, userAddress, outcomeIndex);
                            totalUserBets += parseFloat(ethers.utils.formatEther(betAmount));
                        }

                        if (totalUserBets > 0) {
                            // Check if user has already withdrawn refund
                            userHasWithdrawn = await contract.hasUserWithdrawn(id, userAddress);

                            // Calculate refund (original bets minus fees: 1.5% platform + 1% arbitrator)
                            const platformFee = 150; // 1.5% in basis points
                            const arbitratorFee = 100; // 1% in basis points
                            const totalFeeRate = platformFee + arbitratorFee;
                            const fee = (totalUserBets * totalFeeRate) / 10000;
                            userWinnings = totalUserBets - fee;
                        }
                    } else {
                        // Normal resolution (not a draw)
                        const userBetAmount = await contract.getUserBetAmount(id, userAddress, market.winningOutcome);
                        if (userBetAmount.gt(0)) {
                            // Check if user has already withdrawn
                            userHasWithdrawn = await contract.hasUserWithdrawn(id, userAddress);

                            // Calculate potential winnings
                            const userBetEth = parseFloat(ethers.utils.formatEther(userBetAmount));
                            const winningPool = parseFloat(ethers.utils.formatEther(market.outcomeTotals[market.winningOutcome]));
                            const totalPool = parseFloat(ethers.utils.formatEther(market.totalBets));
                            const grossWinnings = (userBetEth * totalPool) / winningPool;
                            // Deduct fees: 1.5% platform + 1% arbitrator = 2.5%
                            const platformFee = 150; // 1.5% in basis points
                            const arbitratorFee = 100; // 1% in basis points
                            const totalFeeRate = platformFee + arbitratorFee;
                            const fee = (grossWinnings * totalFeeRate) / 10000;
                            userWinnings = grossWinnings - fee;
                        } else {
                            // Check if user bet on any other outcome (losing bet)
                            for (let outcomeIndex = 0; outcomeIndex < market.outcomes.length; outcomeIndex++) {
                                if (outcomeIndex !== market.winningOutcome) {
                                    const losingBetAmount = await contract.getUserBetAmount(id, userAddress, outcomeIndex);
                                    if (losingBetAmount.gt(0)) {
                                        userHasLost = true;
                                        break;
                                    }
                                }
                            }
                        }
                    }

                    // Get arbitrator fee info for current user
                    arbitratorFeeInfo = await contract.getArbitratorFeeInfo(id, userAddress);

                    // If arbitrator and eligible, calculate expected fee from total bets
                    // This shows the correct fee even before any withdrawals
                    if (arbitratorFeeInfo.isArbitrator && arbitratorFeeInfo.isEligible) {
                        const totalBetsEth = parseFloat(ethers.utils.formatEther(market.totalBets));
                        const arbitratorFeeRate = 100; // 1% in basis points
                        const totalExpectedFees = (totalBetsEth * arbitratorFeeRate) / 10000;
                        const eligibleCount = arbitratorFeeInfo.eligibleCount;

                        // Override potentialShare with expected value
                        if (eligibleCount > 0) {
                            arbitratorFeeInfo.expectedShare = totalExpectedFees / eligibleCount;
                        }
                    }
                }

                return renderMarketCard(market, probabilities, 'resolved', userWinnings, userHasLost, false, userHasWithdrawn, arbitratorFeeInfo);
            })
        );

        // Store for filtering
        allResolvedMarkets = marketsHTML;

        marketsContainer.innerHTML = marketsHTML.join('');

    } catch (error) {
        document.getElementById('resolvedMarkets').innerHTML = `<div class="error">Error loading markets: ${error.message}</div>`;
    }
}

function renderMarketCard(market, probabilities, status, userWinnings = null, userHasLost = false, arbitratorHasVoted = false, userHasWithdrawn = false, arbitratorFeeInfo = null) {
    const resolutionDate = new Date(market.resolutionTime * 1000);
    const createdDate = new Date(market.createdAt * 1000);
    const totalBets = ethers.utils.formatEther(market.totalBets);

    let statusClass = 'status-active';
    let statusText = 'Active';
    let isExpired = false;

    if (status === 'resolved') {
        if (market.isDraw) {
            statusClass = 'status-draw';
            statusText = 'Draw - Bets Refunded';
        } else {
            statusClass = 'status-resolved';
            statusText = `Resolved: ${market.outcomes[market.winningOutcome]}`;
        }
    } else if (Date.now() > resolutionDate.getTime()) {
        statusClass = 'status-expired';
        statusText = 'Expired';
        isExpired = true;
    }

    // Check if current user is one of the arbitrators
    const isArbitrator = userAddress && market.arbitrators.some(
        arb => arb.toLowerCase() === userAddress.toLowerCase()
    );

    const outcomesHTML = market.outcomes.map((outcome, index) => {
        const probability = probabilities[index] / 100; // Convert from basis points
        const betAmount = ethers.utils.formatEther(market.outcomeTotals[index]);
        const isWinner = status === 'resolved' && index === market.winningOutcome;

        return `
            <div class="outcome-option ${isWinner ? 'selected' : ''}"
                 onclick="${status === 'active' ? `selectOutcome(${market.id}, ${index})` : ''}">
                <div class="outcome-name">${outcome} ${isWinner ? '🏆' : ''}</div>
                <div class="probability-bar">
                    <div class="probability-fill" style="width: ${probability}%"></div>
                </div>
                <div class="outcome-stats">
                    <span>${probability.toFixed(1)}%</span>
                    <span>${betAmount} ETH</span>
                </div>
            </div>
        `;
    }).join('');

    let actionHTML = '';
    if (status === 'active' && Date.now() < resolutionDate.getTime()) {
        actionHTML = `
            <div class="bet-form">
                <input type="number" id="betAmount${market.id}" step="0.001" min="0.001" placeholder="Bet amount (ETH)">
                <button class="btn btn-success" onclick="placeBet(${market.id})">Place Bet</button>
            </div>
        `;
    } else if (status === 'active' && isExpired && isArbitrator && !arbitratorHasVoted) {
        // Show voting UI for arbitrator when market is expired and they haven't voted yet
        actionHTML = `
            <div class="arbitrator-panel">
                <strong class="arbitrator-title">⚖️ You are an arbitrator for this market</strong>
                <p class="arbitrator-text">Vote on the winning outcome:</p>
                <p class="arbitrator-text">Majority votes needed: ${market.requiredVotes} | Current votes: ${market.totalVotes}</p>
                <div class="bet-form">
                    <select id="winningOutcome${market.id}" class="resolution-select">
                        ${market.outcomes.map((outcome, index) =>
                            `<option value="${index}">${outcome}</option>`
                        ).join('')}
                    </select>
                    <button class="btn btn-resolve" onclick="voteOnOutcome(${market.id})">
                        Cast Vote
                    </button>
                </div>
            </div>
        `;
    } else if (status === 'resolved' && userWinnings !== null && userWinnings > 0) {
        if (market.isDraw) {
            // Draw scenario - show refund message
            if (userHasWithdrawn) {
                actionHTML = `
                    <div class="withdrawn-section">
                        <div class="withdrawn-info">
                            <span class="withdrawn-icon">✅</span>
                            <span class="withdrawn-message">Refund Already Withdrawn (Market Draw)</span>
                            <span class="withdrawn-amount">${userWinnings.toFixed(4)} ETH</span>
                        </div>
                    </div>
                `;
            } else {
                actionHTML = `
                    <div class="winnings-section draw">
                        <div class="winnings-info">
                            <span class="winnings-label">🔄 Market Draw - Refund Available:</span>
                            <span class="winnings-amount-large">${userWinnings.toFixed(4)} ETH</span>
                            <span class="winnings-note">(Your bets refunded minus 2.5% fees: 1.5% platform + 1% arbitrators)</span>
                        </div>
                        <button class="btn btn-success" onclick="withdrawWinnings(${market.id})">Withdraw Refund</button>
                    </div>
                `;
            }
        } else {
            // Normal win scenario
            if (userHasWithdrawn) {
                actionHTML = `
                    <div class="withdrawn-section">
                        <div class="withdrawn-info">
                            <span class="withdrawn-icon">✅</span>
                            <span class="withdrawn-message">Winnings Already Withdrawn</span>
                            <span class="withdrawn-amount">${userWinnings.toFixed(4)} ETH</span>
                        </div>
                    </div>
                `;
            } else {
                actionHTML = `
                    <div class="winnings-section">
                        <div class="winnings-info">
                            <span class="winnings-label">💰 Your Winnings:</span>
                            <span class="winnings-amount-large">${userWinnings.toFixed(4)} ETH</span>
                            <span class="winnings-note">(After 2.5% total fees: 1.5% platform + 1% arbitrators)</span>
                        </div>
                        <button class="btn btn-success" onclick="withdrawWinnings(${market.id})">Withdraw Winnings</button>
                    </div>
                `;
            }
        }
    } else if (status === 'resolved' && userHasLost) {
        actionHTML = `
            <div class="losing-section">
                <div class="losing-info">
                    <span class="losing-icon">😔</span>
                    <span class="losing-message">You did not win this market</span>
                </div>
            </div>
        `;
    }

    // Add arbitrator fee section if user is an arbitrator
    let arbitratorFeeHTML = '';
    if (status === 'resolved' && arbitratorFeeInfo && arbitratorFeeInfo.isArbitrator) {
        // Use expectedShare if available (calculated from total bets), otherwise use potentialShare (from collected fees)
        const feeAmount = arbitratorFeeInfo.expectedShare || parseFloat(ethers.utils.formatEther(arbitratorFeeInfo.potentialShare));
        const totalFees = parseFloat(ethers.utils.formatEther(arbitratorFeeInfo.totalCollectedFees));

        if (arbitratorFeeInfo.isEligible) {
            if (arbitratorFeeInfo.hasClaimed) {
                arbitratorFeeHTML = `
                    <div class="withdrawn-section">
                        <div class="withdrawn-info">
                            <span class="withdrawn-icon">✅</span>
                            <span class="withdrawn-message">Arbitrator Fee Already Claimed</span>
                            <span class="withdrawn-amount">${feeAmount.toFixed(4)} ETH</span>
                        </div>
                    </div>
                `;
            } else if (feeAmount > 0) {
                // Show claimable fee with green section and button
                const totalExpectedFees = (parseFloat(ethers.utils.formatEther(market.totalBets)) * 100) / 10000;

                arbitratorFeeHTML = `
                    <div class="winnings-section">
                        <div class="winnings-info">
                            <span class="winnings-label">⚖️ Arbitrator Fee Available:</span>
                            <span class="winnings-amount-large">${feeAmount.toFixed(4)} ETH</span>
                            <span class="winnings-note">(Your share: 1 of ${arbitratorFeeInfo.eligibleCount} eligible arbitrators from ${totalExpectedFees.toFixed(4)} ETH total)</span>
                        </div>
                        <button class="btn btn-success" onclick="claimArbitratorFee(${market.id})">Claim Arbitrator Fee</button>
                    </div>
                `;
            } else {
                // feeAmount is 0 - show informational message (no button)
                arbitratorFeeHTML = `
                    <div class="withdrawn-section">
                        <div class="withdrawn-info">
                            <span class="withdrawn-icon">ℹ️</span>
                            <span class="withdrawn-message">No Arbitrator Fee Available</span>
                            <span class="withdrawn-amount">0.0000 ETH</span>
                        </div>
                        <div class="winnings-note" style="text-align: center; margin-top: 8px;">
                            (No bets were placed on this market)
                        </div>
                    </div>
                `;
            }
        } else {
            // Arbitrator but not eligible (didn't vote or voted incorrectly)
            let reason;
            if (market.isDraw) {
                reason = "You did not vote on this market";
            } else {
                reason = !arbitratorFeeInfo.hasVoted
                    ? "You did not vote on this market"
                    : `You voted for "${market.outcomes[arbitratorFeeInfo.votedOutcome]}" but the winning outcome was "${market.outcomes[market.winningOutcome]}"`;
            }

            const totalExpectedFees = (parseFloat(ethers.utils.formatEther(market.totalBets)) * 100) / 10000;

            arbitratorFeeHTML = `
                <div class="losing-section">
                    <div class="losing-info">
                        <span class="losing-icon">⚖️</span>
                        <span class="losing-message">Not Eligible for Arbitrator Fee</span>
                        <span class="losing-reason">${reason}</span>
                        <span class="losing-details">${totalExpectedFees.toFixed(4)} ETH distributed to ${arbitratorFeeInfo.eligibleCount} eligible arbitrator(s)</span>
                    </div>
                </div>
            `;
        }
    }

    return `
        <div class="market-card" data-category="${market.category}">
            <div class="market-header">
                <div class="market-title">${market.description}${getCategoryBadge(market.category)}</div>
                <div class="market-status ${statusClass}">${statusText}</div>
            </div>

            <div class="outcomes-grid">
                ${outcomesHTML}
            </div>

            ${actionHTML}

            ${arbitratorFeeHTML}

            <div class="market-info">
                <div class="info-item">
                    <div class="info-label">Total Bets</div>
                    <div class="info-value">${totalBets} ETH</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Resolution Date</div>
                    <div class="info-value">
                        ${resolutionDate.toLocaleDateString()}
                        <div class="info-subvalue">${resolutionDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</div>
                    </div>
                </div>
                <div class="info-item">
                    <div class="info-label">Created</div>
                    <div class="info-value">${createdDate.toLocaleDateString()}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Creator</div>
                    <div class="info-value">${market.creator.slice(0, 6)}...${market.creator.slice(-4)}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Arbitrators</div>
                    <div class="info-value">${market.arbitrators.length} total</div>
                    <div class="info-subvalue">${market.arbitrators.map(a => a.slice(0, 6) + '...' + a.slice(-4)).join(', ')}</div>
                </div>
            </div>
        </div>
    `;
}

function selectOutcome(marketId, outcomeIndex) {
    selectedMarketId = marketId;
    selectedOutcome = outcomeIndex;

    // Visual feedback
    document.querySelectorAll(`[onclick*="selectOutcome(${marketId}"]`).forEach(el => {
        el.classList.remove('selected');
    });
    event.target.closest('.outcome-option').classList.add('selected');
}

async function placeBet(marketId) {
    if (!contract) {
        showError('Please connect your wallet first');
        return;
    }

    if (selectedMarketId !== marketId || selectedOutcome === null) {
        showError('Please select an outcome first');
        return;
    }

    try {
        const betAmount = document.getElementById(`betAmount${marketId}`).value;
        if (!betAmount || parseFloat(betAmount) <= 0) {
            showError('Please enter a valid bet amount');
            return;
        }

        showSuccess('Placing bet... Please confirm transaction in your wallet.');

        const tx = await contract.placeBet(
            marketId,
            selectedOutcome,
            { value: ethers.utils.parseEther(betAmount) }
        );

        showSuccess('Transaction submitted. Waiting for confirmation...');
        await tx.wait();

        showSuccess('Bet placed successfully!');

        // Reset selection and refresh markets
        selectedMarketId = null;
        selectedOutcome = null;
        document.getElementById(`betAmount${marketId}`).value = '';

        await loadActiveMarkets();
        await loadMyBets();

    } catch (error) {
        showError(error);
    }
}

async function voteOnOutcome(marketId) {
    if (!contract) {
        showError('Please connect your wallet first');
        return;
    }

    try {
        const selectedOutcome = parseInt(document.getElementById(`winningOutcome${marketId}`).value);

        showSuccess('Casting vote... Please confirm transaction in your wallet.');

        const tx = await contract.voteOnOutcome(marketId, selectedOutcome);

        showSuccess('Transaction submitted. Waiting for confirmation...');
        await tx.wait();

        showSuccess('Vote cast successfully! Market will auto-resolve when required votes are reached.');

        // Refresh markets
        await loadActiveMarkets();
        await loadResolvedMarkets();

    } catch (error) {
        showError(error);
    }
}

async function withdrawWinnings(marketId) {
    if (!contract) {
        showError('Please connect your wallet first');
        return;
    }

    try {
        showSuccess('Withdrawing winnings... Please confirm transaction in your wallet.');

        const tx = await contract.withdrawWinnings(marketId);

        showSuccess('Transaction submitted. Waiting for confirmation...');
        await tx.wait();

        showSuccess('Winnings withdrawn successfully!');

        await loadResolvedMarkets();
        await loadMyBets();

    } catch (error) {
        showError(error);
    }
}

async function claimArbitratorFee(marketId) {
    if (!contract) {
        showError('Please connect your wallet first');
        return;
    }

    try {
        showSuccess('Claiming arbitrator fee... Please confirm transaction in your wallet.');

        const tx = await contract.claimArbitratorFee(marketId);

        showSuccess('Transaction submitted. Waiting for confirmation...');
        await tx.wait();

        showSuccess('Arbitrator fee claimed successfully!');

        await loadResolvedMarkets();
        await loadMyBets();

    } catch (error) {
        showError(error);
    }
}

async function loadMyBets() {
    if (!contract || !userAddress) return;

    try {
        const bets = await contract.getUserBets(userAddress);
        const betsContainer = document.getElementById('myBets');

        if (bets.length === 0) {
            betsContainer.innerHTML = `
                <div class="no-markets">
                    <h3>No bets yet</h3>
                    <p>Your bets will appear here after you place them</p>
                </div>
            `;
            return;
        }

        // Group bets by market
        const betsByMarket = {};
        for (const bet of bets) {
            const marketId = bet.marketId.toString();
            if (!betsByMarket[marketId]) {
                betsByMarket[marketId] = [];
            }
            betsByMarket[marketId].push(bet);
        }

        const betsHTML = await Promise.all(
            Object.keys(betsByMarket).map(async (marketId) => {
                try {
                    const market = await contract.getMarketInfo(marketId);
                    const marketBets = betsByMarket[marketId];
                    const probabilities = await contract.getOutcomeProbabilities(marketId);

                    // Consolidate bets by outcome
                    const betsByOutcome = {};
                    for (const bet of marketBets) {
                        const outcomeIndex = bet.outcome;
                        if (!betsByOutcome[outcomeIndex]) {
                            betsByOutcome[outcomeIndex] = {
                                outcome: market.outcomes[outcomeIndex],
                                outcomeIndex: outcomeIndex,
                                totalAmount: 0,
                                bets: []
                            };
                        }
                        betsByOutcome[outcomeIndex].totalAmount += parseFloat(ethers.utils.formatEther(bet.amount));
                        betsByOutcome[outcomeIndex].bets.push(bet);
                    }

                    // Calculate if user has winning bets and potential winnings
                    let hasWinningBet = false;
                    let totalWinningBetAmount = 0;
                    let potentialWinnings = 0;

                    if (market.resolved) {
                        for (const bet of marketBets) {
                            if (bet.outcome === market.winningOutcome) {
                                hasWinningBet = true;
                                totalWinningBetAmount += parseFloat(ethers.utils.formatEther(bet.amount));
                            }
                        }

                        // Calculate potential winnings if user has winning bets
                        if (hasWinningBet && market.totalBets > 0) {
                            const winningPool = parseFloat(ethers.utils.formatEther(market.outcomeTotals[market.winningOutcome]));
                            const totalPool = parseFloat(ethers.utils.formatEther(market.totalBets));
                            const grossWinnings = (totalWinningBetAmount * totalPool) / winningPool;
                            const platformFee = 250; // 2.5% in basis points
                            const fee = (grossWinnings * platformFee) / 10000;
                            potentialWinnings = grossWinnings - fee;
                        }
                    }

                    const betsListHTML = Object.values(betsByOutcome).map(outcomeData => {
                        const isWinningBet = market.resolved && outcomeData.outcomeIndex === market.winningOutcome;
                        const probability = (probabilities[outcomeData.outcomeIndex] / 100).toFixed(1);

                        // Calculate potential earnings for active markets
                        let potentialEarnings = 0;
                        if (!market.resolved && market.totalBets > 0) {
                            const outcomePool = parseFloat(ethers.utils.formatEther(market.outcomeTotals[outcomeData.outcomeIndex]));
                            const totalPool = parseFloat(ethers.utils.formatEther(market.totalBets));
                            if (outcomePool > 0) {
                                const grossWinnings = (outcomeData.totalAmount * totalPool) / outcomePool;
                                const platformFee = 250; // 2.5% in basis points
                                const fee = (grossWinnings * platformFee) / 10000;
                                potentialEarnings = grossWinnings - fee;
                            }
                        }

                        const betCountText = outcomeData.bets.length > 1 ? ` (${outcomeData.bets.length} bets)` : '';

                        return `
                            <div class="bet-item ${isWinningBet ? 'bet-winner' : ''}">
                                <div class="bet-outcome">
                                    ${outcomeData.outcome} ${isWinningBet ? '🏆' : ''}${betCountText}
                                    <span class="outcome-probability">${probability}%</span>
                                </div>
                                <div class="bet-amount">
                                    <div class="amount-label">Total Bet:</div>
                                    <div class="amount-value">${outcomeData.totalAmount.toFixed(4)} ETH</div>
                                </div>
                                ${!market.resolved && potentialEarnings > 0 ? `
                                    <div class="potential-earnings">
                                        <div class="earnings-label">Potential Payout:</div>
                                        <div class="earnings-value">💰 ${potentialEarnings.toFixed(4)} ETH</div>
                                    </div>
                                ` : ''}
                            </div>
                        `;
                    }).join('');

                    // Create winnings panel if market is resolved and user has winning bets
                    let winningsPanel = '';
                    if (market.resolved && hasWinningBet) {
                        // Check if user has already withdrawn
                        const hasWithdrawn = await contract.hasUserWithdrawn(marketId, userAddress);

                        if (hasWithdrawn) {
                            winningsPanel = `
                                <div class="winnings-panel withdrawn">
                                    <div class="winnings-header">
                                        <span class="winnings-title">✅ Winnings Withdrawn</span>
                                    </div>
                                    <div class="winnings-details">
                                        <div class="winnings-amount">
                                            <span class="winnings-label">Amount Withdrawn:</span>
                                            <span class="winnings-value">${potentialWinnings.toFixed(4)} ETH</span>
                                        </div>
                                    </div>
                                </div>
                            `;
                        } else {
                            winningsPanel = `
                                <div class="winnings-panel">
                                    <div class="winnings-header">
                                        <span class="winnings-title">💰 Your Winnings</span>
                                    </div>
                                    <div class="winnings-details">
                                        <div class="winnings-amount">
                                            <span class="winnings-label">Potential Payout:</span>
                                            <span class="winnings-value">${potentialWinnings.toFixed(4)} ETH</span>
                                        </div>
                                        <button class="btn btn-success" onclick="withdrawWinnings(${marketId})" style="margin-top: 10px;">
                                            Withdraw Winnings
                                        </button>
                                        <div class="winnings-note">
                                            (After 2.5% total fees: 1.5% platform + 1% arbitrators)
                                        </div>
                                    </div>
                                </div>
                            `;
                        }
                    }

                    return `
                        <div class="market-card" data-category="${market.category}">
                            <div class="market-header">
                                <div class="market-title">${market.description}${getCategoryBadge(market.category)}</div>
                                <div class="market-status ${market.resolved ? (market.isDraw ? 'status-draw' : 'status-resolved') : 'status-active'}">
                                    ${market.resolved ? (market.isDraw ? 'Draw - Bets Refunded' : `Resolved: ${market.outcomes[market.winningOutcome]}`) : 'Active'}
                                </div>
                            </div>
                            <div class="bets-section">
                                <strong class="bets-label">Your Bets:</strong>
                                <div class="bets-grid">
                                    ${betsListHTML}
                                </div>
                            </div>
                            ${winningsPanel}
                        </div>
                    `;
                } catch (error) {
                    return `<div class="error">Error loading market ${marketId}: ${error.message}</div>`;
                }
            })
        );

        // Store for filtering
        allMyBetsMarkets = betsHTML;

        betsContainer.innerHTML = betsHTML.join('');

    } catch (error) {
        document.getElementById('myBets').innerHTML = `<div class="error">Error loading bets: ${error.message}</div>`;
    }
}

// Extract clean error message from blockchain error
function extractErrorMessage(error) {
    const errorString = error.message || error.toString();

    // Common error patterns from smart contracts (order matters - most specific first)
    const patterns = [
        /reverted with reason string '([^']+)'/,     // Matches: reverted with reason string 'No winning bet found'
        /reason="([^"]+)"/,                          // Matches: reason="Already withdrawn"
        /"message":"([^"]+)"/,                       // Matches JSON errors
    ];

    // Try to extract clean message
    for (const pattern of patterns) {
        const match = errorString.match(pattern);
        if (match && match[1]) {
            return match[1].trim();
        }
    }

    // Check for common user-friendly errors
    if (errorString.includes('user rejected') || errorString.includes('User denied')) {
        return 'Transaction cancelled by user';
    }
    if (errorString.includes('insufficient funds')) {
        return 'Insufficient funds in wallet';
    }
    if (errorString.includes('nonce')) {
        return 'Transaction error. Try resetting your MetaMask account.';
    }

    // Check for specific contract errors that need better messaging
    if (errorString.includes('Invalid number of outcomes')) {
        return 'Invalid number of outcomes. You must provide between 2 and 10 outcomes.';
    }
    if (errorString.includes('Market creator cannot bet on their own market')) {
        return 'You cannot bet on a market you created.';
    }
    if (errorString.includes('Arbitrator cannot bet on this market')) {
        return 'As an arbitrator, you cannot bet on this market.';
    }
    if (errorString.includes('Minimum 3 arbitrators required')) {
        return 'You must provide at least 3 arbitrator addresses.';
    }
    if (errorString.includes('Maximum 21 arbitrators allowed')) {
        return 'You cannot have more than 21 arbitrators.';
    }
    if (errorString.includes('Duplicate arbitrator addresses')) {
        return 'Arbitrator addresses must be unique.';
    }
    if (errorString.includes('Creator cannot be arbitrator')) {
        return 'You cannot be an arbitrator for your own market.';
    }
    if (errorString.includes('Only arbitrator can vote')) {
        return 'Only designated arbitrators can vote on this market.';
    }
    if (errorString.includes('Already voted')) {
        return 'You have already cast your vote on this market.';
    }
    if (errorString.includes('Market not yet resolvable')) {
        return 'Market resolution time has not been reached yet.';
    }

    // If no pattern matched, return a generic message
    return 'Transaction failed. Please try again.';
}

function showError(errorMessage) {
    // Extract clean message if it's an error object
    const cleanMessage = typeof errorMessage === 'object'
        ? extractErrorMessage(errorMessage)
        : errorMessage;

    showModal('Error', cleanMessage, 'error');
}

function showSuccess(message) {
    showModal('Success', message, 'success');
}

function showModal(title, message, type) {
    // Create modal if it doesn't exist
    let modal = document.getElementById('notification-modal');
    if (!modal) {
        modal = document.createElement('div');
        modal.id = 'notification-modal';
        modal.className = 'modal-overlay';
        modal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h3 class="modal-title"></h3>
                    <button class="modal-close" onclick="dismissModal()">×</button>
                </div>
                <div class="modal-body"></div>
                <div class="modal-footer">
                    <button class="btn" onclick="dismissModal()">OK</button>
                </div>
            </div>
        `;
        document.body.appendChild(modal);

        // Close on overlay click
        modal.addEventListener('click', function(e) {
            if (e.target === modal) {
                dismissModal();
            }
        });

        // Close on ESC key
        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape' && modal.classList.contains('show')) {
                dismissModal();
            }
        });
    }

    // Update modal content
    const modalContent = modal.querySelector('.modal-content');
    modalContent.className = `modal-content modal-${type}`;
    modal.querySelector('.modal-title').textContent = title;
    modal.querySelector('.modal-body').textContent = message;

    // Show modal
    modal.classList.add('show');

    // Clear any existing timeout
    if (window.modalTimeout) {
        clearTimeout(window.modalTimeout);
    }

    // Auto-dismiss after 10 seconds (only for success messages)
    if (type === 'success') {
        window.modalTimeout = setTimeout(() => {
            dismissModal();
        }, 10000);
    }
}

function dismissModal() {
    const modal = document.getElementById('notification-modal');
    if (modal) {
        modal.classList.remove('show');
    }
    if (window.modalTimeout) {
        clearTimeout(window.modalTimeout);
    }
}

// Keep these for backwards compatibility (now just call dismissModal)
function dismissError() {
    dismissModal();
}

function dismissSuccess() {
    dismissModal();
}
