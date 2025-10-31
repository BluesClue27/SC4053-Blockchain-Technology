const hre = require("hardhat");

async function main() {
    console.log("Deploying PredictionMarket contract...");

    // Get all signers (deployer + arbitrators)
    const [deployer, acc1, acc2, acc3] = await hre.ethers.getSigners();
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
    const resolutionTime = Math.floor(Date.now() / 1000) + (60 * 5); // 5 mins from now

    // Use accounts 1, 2, 3 as arbitrators (not the deployer)
    const arbitrators = [acc1.address, acc2.address, acc3.address];

    console.log("Using arbitrators:", arbitrators);

    const tx = await predictionMarket.createMarket(
        "Will Bitcoin reach $100,000 by the end of 2025?",
        ["Yes", "No"],
        resolutionTime,
        arbitrators, // Use multiple arbitrators
        { value: hre.ethers.parseEther("0.001") }
    );

    await tx.wait();
    console.log("Sample market created with", arbitrators.length, "arbitrators!");

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

    // Update frontend with new contract address
    const frontendPath = './frontend/js/app.js';
    let frontendCode = fs.readFileSync(frontendPath, 'utf8');

    // Replace the contract address using regex
    const addressRegex = /const CONTRACT_ADDRESS = ['"]0x[a-fA-F0-9]{40}['"]/;
    frontendCode = frontendCode.replace(
        addressRegex,
        `const CONTRACT_ADDRESS = '${contractAddress}'`
    );

    fs.writeFileSync(frontendPath, frontendCode);
    console.log("✅ Frontend updated with new contract address!");
    console.log("\n⚠️  IMPORTANT: Hard refresh your browser (Ctrl+Shift+R) to clear cache!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });