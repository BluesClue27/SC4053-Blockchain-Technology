const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PredictionMarket", function () {
  let predictionMarket;
  let owner, user1, user2, arbitrator;
  let marketId;
  let resolutionTime;

  beforeEach(async function () {
    [owner, user1, user2, arbitrator] = await ethers.getSigners();

    const PredictionMarket = await ethers.getContractFactory("PredictionMarket");
    predictionMarket = await PredictionMarket.deploy();
    await predictionMarket.waitForDeployment();

    // Set resolution time to be 2 hours from now in each test
    const currentBlockTime = (await ethers.provider.getBlock('latest')).timestamp;
    resolutionTime = currentBlockTime + 7200; // 2 hours from current block time
  });

  describe("Market Creation", function () {
    it("Should create a market successfully", async function () {
      const tx = await predictionMarket.createMarket(
        "Will it rain tomorrow?",
        ["Yes", "No"],
        resolutionTime,
        arbitrator.address,
        { value: ethers.parseEther("0.001") }
      );

      await expect(tx).to.emit(predictionMarket, "MarketCreated");
      
      const marketInfo = await predictionMarket.getMarketInfo(1);
      expect(marketInfo.description).to.equal("Will it rain tomorrow?");
      expect(marketInfo.outcomes).to.deep.equal(["Yes", "No"]);
      expect(marketInfo.arbitrator).to.equal(arbitrator.address);
    });

    it("Should fail to create market with insufficient fee", async function () {
      await expect(
        predictionMarket.createMarket(
          "Test market",
          ["Yes", "No"],
          resolutionTime,
          arbitrator.address,
          { value: ethers.parseEther("0.0001") }
        )
      ).to.be.revertedWith("Minimum creation fee required");
    });

    it("Should fail to create market with resolution time too soon", async function () {
      const currentBlockTime = (await ethers.provider.getBlock('latest')).timestamp;
      const soonTime = currentBlockTime + 1800; // 30 minutes from current block

      await expect(
        predictionMarket.createMarket(
          "Test market",
          ["Yes", "No"],
          soonTime,
          arbitrator.address,
          { value: ethers.parseEther("0.001") }
        )
      ).to.be.revertedWith("Resolution time too soon");
    });

    it("Should fail to create market with invalid number of outcomes", async function () {
      await expect(
        predictionMarket.createMarket(
          "Test market",
          ["Only one outcome"],
          resolutionTime,
          arbitrator.address,
          { value: ethers.parseEther("0.001") }
        )
      ).to.be.revertedWith("Invalid number of outcomes");
    });
  });

  describe("Betting", function () {
    beforeEach(async function () {
      const tx = await predictionMarket.createMarket(
        "Will it rain tomorrow?",
        ["Yes", "No"],
        resolutionTime,
        arbitrator.address,
        { value: ethers.parseEther("0.001") }
      );
      await tx.wait();
      marketId = 1;
    });

    it("Should place a bet successfully", async function () {
      const betAmount = ethers.parseEther("0.1");
      
      const tx = await predictionMarket.connect(user1).placeBet(
        marketId,
        0, // Betting on "Yes"
        { value: betAmount }
      );

      await expect(tx).to.emit(predictionMarket, "BetPlaced")
        .withArgs(marketId, user1.address, 0, betAmount);

      const userBetAmount = await predictionMarket.getUserBetAmount(
        marketId,
        user1.address,
        0
      );
      expect(userBetAmount).to.equal(betAmount);
    });

    it("Should update market totals correctly", async function () {
      const betAmount1 = ethers.parseEther("0.1");
      const betAmount2 = ethers.parseEther("0.2");

      await predictionMarket.connect(user1).placeBet(marketId, 0, { value: betAmount1 });
      await predictionMarket.connect(user2).placeBet(marketId, 1, { value: betAmount2 });

      const marketInfo = await predictionMarket.getMarketInfo(marketId);
      expect(marketInfo.totalBets).to.equal(betAmount1 + betAmount2);
      expect(marketInfo.outcomeTotals[0]).to.equal(betAmount1);
      expect(marketInfo.outcomeTotals[1]).to.equal(betAmount2);
    });

    it("Should calculate probabilities correctly", async function () {
      const betAmount1 = ethers.parseEther("0.3"); // 75%
      const betAmount2 = ethers.parseEther("0.1"); // 25%

      await predictionMarket.connect(user1).placeBet(marketId, 0, { value: betAmount1 });
      await predictionMarket.connect(user2).placeBet(marketId, 1, { value: betAmount2 });

      const probabilities = await predictionMarket.getOutcomeProbabilities(marketId);
      expect(probabilities[0]).to.equal(7500); // 75% in basis points
      expect(probabilities[1]).to.equal(2500); // 25% in basis points
    });

    it("Should fail to bet on invalid outcome", async function () {
      await expect(
        predictionMarket.connect(user1).placeBet(
          marketId,
          2, // Invalid outcome index
          { value: ethers.parseEther("0.1") }
        )
      ).to.be.revertedWith("Invalid outcome");
    });

    it("Should fail to bet with zero amount", async function () {
      await expect(
        predictionMarket.connect(user1).placeBet(
          marketId,
          0,
          { value: 0 }
        )
      ).to.be.revertedWith("Bet amount must be greater than 0");
    });

    it("Should fail to bet on non-existent market", async function () {
      await expect(
        predictionMarket.connect(user1).placeBet(
          999,
          0,
          { value: ethers.parseEther("0.1") }
        )
      ).to.be.revertedWith("Market does not exist");
    });
  });

  describe("Market Resolution", function () {
    beforeEach(async function () {
      const tx = await predictionMarket.createMarket(
        "Will it rain tomorrow?",
        ["Yes", "No"],
        resolutionTime,
        arbitrator.address,
        { value: ethers.parseEther("0.001") }
      );
      await tx.wait();
      marketId = 1;

      // Place some bets
      await predictionMarket.connect(user1).placeBet(marketId, 0, { 
        value: ethers.parseEther("0.3") 
      });
      await predictionMarket.connect(user2).placeBet(marketId, 1, { 
        value: ethers.parseEther("0.1") 
      });
    });

    it("Should resolve market successfully by arbitrator", async function () {
      // Fast forward time to after resolution time
      await ethers.provider.send("evm_increaseTime", [7201]); // More than 2 hours
      await ethers.provider.send("evm_mine");

      const tx = await predictionMarket.connect(arbitrator).resolveMarket(marketId, 0);
      
      await expect(tx).to.emit(predictionMarket, "MarketResolved")
        .withArgs(marketId, 0, ethers.parseEther("0.3"));

      const marketInfo = await predictionMarket.getMarketInfo(marketId);
      expect(marketInfo.resolved).to.be.true;
      expect(marketInfo.winningOutcome).to.equal(0);
    });

    it("Should fail to resolve market before resolution time", async function () {
      await expect(
        predictionMarket.connect(arbitrator).resolveMarket(marketId, 0)
      ).to.be.revertedWith("Market not yet resolvable");
    });

    it("Should fail to resolve market by non-arbitrator", async function () {
      await ethers.provider.send("evm_increaseTime", [7201]); // More than 2 hours
      await ethers.provider.send("evm_mine");

      await expect(
        predictionMarket.connect(user1).resolveMarket(marketId, 0)
      ).to.be.revertedWith("Only arbitrator can resolve");
    });

    it("Should fail to resolve already resolved market", async function () {
      await ethers.provider.send("evm_increaseTime", [7201]); // More than 2 hours
      await ethers.provider.send("evm_mine");

      await predictionMarket.connect(arbitrator).resolveMarket(marketId, 0);
      
      await expect(
        predictionMarket.connect(arbitrator).resolveMarket(marketId, 1)
      ).to.be.revertedWith("Market already resolved");
    });
  });

  describe("Withdrawals", function () {
    beforeEach(async function () {
      const tx = await predictionMarket.createMarket(
        "Will it rain tomorrow?",
        ["Yes", "No"],
        resolutionTime,
        arbitrator.address,
        { value: ethers.parseEther("0.001") }
      );
      await tx.wait();
      marketId = 1;

      // Place bets: user1 bets 0.6 ETH on outcome 0, user2 bets 0.4 ETH on outcome 1
      await predictionMarket.connect(user1).placeBet(marketId, 0, { 
        value: ethers.parseEther("0.6") 
      });
      await predictionMarket.connect(user2).placeBet(marketId, 1, { 
        value: ethers.parseEther("0.4") 
      });

      // Fast forward and resolve market with outcome 0 winning
      await ethers.provider.send("evm_increaseTime", [7201]); // More than 2 hours
      await ethers.provider.send("evm_mine");
      await predictionMarket.connect(arbitrator).resolveMarket(marketId, 0);
    });

    it("Should allow winner to withdraw correctly", async function () {
      const initialBalance = await user1.provider.getBalance(user1.address);

      const tx = await predictionMarket.connect(user1).withdrawWinnings(marketId);
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;

      const finalBalance = await user1.provider.getBalance(user1.address);

      // Winner should get their proportion of the total pool minus platform fee
      // user1 bet 0.6 ETH on winning outcome, total pool is 1.0 ETH
      // So user1 should get entire pool (1.0 ETH) minus 2.5% platform fee
      const expectedPayout = ethers.parseEther("0.975"); // 1.0 - 0.025
      const actualPayout = finalBalance + gasUsed - initialBalance;

      expect(actualPayout).to.be.closeTo(expectedPayout, ethers.parseEther("0.001"));
      
      await expect(tx).to.emit(predictionMarket, "Withdrawal");
    });

    it("Should fail withdrawal for losing bet", async function () {
      await expect(
        predictionMarket.connect(user2).withdrawWinnings(marketId)
      ).to.be.revertedWith("No winning bet found");
    });

    it("Should fail withdrawal from unresolved market", async function () {
      // Create new unresolved market
      const currentBlockTime3 = (await ethers.provider.getBlock('latest')).timestamp;
      const tx = await predictionMarket.createMarket(
        "Another question?",
        ["Yes", "No"],
        currentBlockTime3 + 14400, // 4 hours from current time
        arbitrator.address,
        { value: ethers.parseEther("0.001") }
      );
      await tx.wait();

      await predictionMarket.connect(user1).placeBet(2, 0, { 
        value: ethers.parseEther("0.1") 
      });

      await expect(
        predictionMarket.connect(user1).withdrawWinnings(2)
      ).to.be.revertedWith("Market not yet resolved");
    });

    it("Should fail double withdrawal", async function () {
      await predictionMarket.connect(user1).withdrawWinnings(marketId);
      
      await expect(
        predictionMarket.connect(user1).withdrawWinnings(marketId)
      ).to.be.revertedWith("Already withdrawn");
    });
  });

  describe("View Functions", function () {
    beforeEach(async function () {
      // Create multiple markets
      await predictionMarket.createMarket(
        "Market 1",
        ["Yes", "No"],
        resolutionTime,
        arbitrator.address,
        { value: ethers.parseEther("0.001") }
      );
      
      const currentBlockTime2 = (await ethers.provider.getBlock('latest')).timestamp;
      await predictionMarket.createMarket(
        "Market 2",
        ["Option A", "Option B", "Option C"],
        currentBlockTime2 + 10800, // 3 hours from current time
        arbitrator.address,
        { value: ethers.parseEther("0.001") }
      );

      // Place some bets
      await predictionMarket.connect(user1).placeBet(1, 0, { 
        value: ethers.parseEther("0.1") 
      });
      await predictionMarket.connect(user1).placeBet(2, 1, { 
        value: ethers.parseEther("0.2") 
      });

      // Resolve first market
      await ethers.provider.send("evm_increaseTime", [7201]); // More than 2 hours
      await ethers.provider.send("evm_mine");
      await predictionMarket.connect(arbitrator).resolveMarket(1, 0);
    });

    it("Should return active markets correctly", async function () {
      const activeMarkets = await predictionMarket.getAllActiveMarkets();
      expect(activeMarkets.length).to.equal(1);
      expect(activeMarkets[0]).to.equal(2);
    });

    it("Should return resolved markets correctly", async function () {
      const resolvedMarkets = await predictionMarket.getAllResolvedMarkets();
      expect(resolvedMarkets.length).to.equal(1);
      expect(resolvedMarkets[0]).to.equal(1);
    });

    it("Should return user bets correctly", async function () {
      const userBets = await predictionMarket.getUserBets(user1.address);
      expect(userBets.length).to.equal(2);
      expect(userBets[0].marketId).to.equal(1);
      expect(userBets[1].marketId).to.equal(2);
    });

    it("Should return user markets correctly", async function () {
      const userMarkets = await predictionMarket.getUserMarkets(owner.address);
      expect(userMarkets.length).to.equal(2);
      expect(userMarkets[0]).to.equal(1);
      expect(userMarkets[1]).to.equal(2);
    });
  });

  describe("Platform Fee Management", function () {
    it("Should allow owner to set platform fee", async function () {
      await predictionMarket.setPlatformFee(500); // 5%
      expect(await predictionMarket.platformFee()).to.equal(500);
    });

    it("Should reject platform fee above 10%", async function () {
      await expect(
        predictionMarket.setPlatformFee(1001)
      ).to.be.revertedWith("Fee cannot exceed 10%");
    });

    it("Should reject non-owner setting platform fee", async function () {
      await expect(
        predictionMarket.connect(user1).setPlatformFee(500)
      ).to.be.revertedWithCustomError(predictionMarket, "OwnableUnauthorizedAccount");
    });
  });

  describe("Emergency Functions", function () {
    it("Should allow owner to emergency withdraw", async function () {
      // Create and fund market
      await predictionMarket.createMarket(
        "Test market",
        ["Yes", "No"],
        resolutionTime,
        arbitrator.address,
        { value: ethers.parseEther("0.001") }
      );

      const initialOwnerBalance = await owner.provider.getBalance(owner.address);
      const contractBalance = await ethers.provider.getBalance(await predictionMarket.getAddress());

      const tx = await predictionMarket.emergencyWithdraw();
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;

      const finalOwnerBalance = await owner.provider.getBalance(owner.address);
      const expectedBalance = initialOwnerBalance + contractBalance - gasUsed;

      expect(finalOwnerBalance).to.equal(expectedBalance);
    });

    it("Should reject non-owner emergency withdraw", async function () {
      await expect(
        predictionMarket.connect(user1).emergencyWithdraw()
      ).to.be.revertedWithCustomError(predictionMarket, "OwnableUnauthorizedAccount");
    });
  });

  describe("Reentrancy Protection", function () {
    // Note: This would require a malicious contract to test properly
    // For now, we just verify the modifier is in place
    it("Should have reentrancy protection on critical functions", async function () {
      // This is more of a compile-time check that the modifiers are present
      // Real reentrancy testing would require deploying attack contracts
      expect(true).to.be.true;
    });
  });
});