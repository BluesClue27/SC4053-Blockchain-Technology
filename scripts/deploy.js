const hre = require("hardhat");

async function main() {
    console.log("Deploying PredictionMarket contract...");

    // Get the ContractFactory and Signers
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", hre.ethers.formatEther(await hre.ethers.provider.getBalance(deployer.address)));

    // Deploy the contract
    const PredictionMarket = await hre.ethers.getContractFactory("PredictionMarket");
    const predictionMarket = await PredictionMarket.deploy();

    await predictionMarket.waitForDeployment();
    const contractAddress = await predictionMarket.getAddress();

    console.log("PredictionMarket deployed to:", contractAddress);

    // Verify the contract on Etherscan (if not on localhost)
    if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
        console.log("Waiting for block confirmations...");
        await predictionMarket.deploymentTransaction().wait(5);

        try {
            await hre.run("verify:verify", {
                address: contractAddress,
                constructorArguments: [],
            });
            console.log("Contract verified on Etherscan");
        } catch (error) {
            console.log("Error verifying contract:", error.message);
        }
    }

    // Create a sample market for testing
    console.log("\nCreating sample market...");
    const resolutionTime = Math.floor(Date.now() / 1000) + (24 * 60 * 60); // 24 hours from now

    const tx = await predictionMarket.createMarket(
        "Will Bitcoin reach $100,000 by the end of 2024?",
        ["Yes", "No"],
        resolutionTime,
        deployer.address, // Use deployer as arbitrator for testing
        { value: hre.ethers.parseEther("0.001") }
    );

    await tx.wait();
    console.log("Sample market created!");

    // Get market info
    const marketInfo = await predictionMarket.getMarketInfo(1);
    console.log("Market Description:", marketInfo.description);
    console.log("Market Outcomes:", marketInfo.outcomes);

    console.log("\nDeployment Summary:");
    console.log("===================");
    console.log("Contract Address:", contractAddress);
    console.log("Network:", hre.network.name);
    console.log("Deployer:", deployer.address);
    console.log("Sample Market ID: 1");

    // Save deployment info
    const fs = require('fs');
    const deploymentInfo = {
        contractAddress: contractAddress,
        network: hre.network.name,
        deployer: deployer.address,
        deploymentTime: new Date().toISOString(),
        sampleMarketId: 1
    };

    fs.writeFileSync('deployment.json', JSON.stringify(deploymentInfo, null, 2));
    console.log("Deployment info saved to deployment.json");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });