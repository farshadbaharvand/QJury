// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/QJuryRegistry.sol";
import "../contracts/QJuryVote.sol";
import "../contracts/QJuryDispute.sol";
import "../contracts/QJuryReward.sol";
import "../contracts/QuantumRandomOracle.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying QJury contracts...");
        console.log("Deployer address:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy contracts in dependency order
        console.log("Deploying QJuryRegistry...");
        QJuryRegistry registry = new QJuryRegistry();
        console.log("QJuryRegistry deployed at:", address(registry));
        
        console.log("Deploying QuantumRandomOracle...");
        QuantumRandomOracle quantumOracle = new QuantumRandomOracle();
        console.log("QuantumRandomOracle deployed at:", address(quantumOracle));
        
        console.log("Deploying QJuryVote...");
        QJuryVote voteContract = new QJuryVote(address(registry));
        console.log("QJuryVote deployed at:", address(voteContract));
        
        console.log("Deploying QJuryDispute...");
        QJuryDispute disputeContract = new QJuryDispute(
            address(registry),
            address(voteContract),
            address(quantumOracle)
        );
        console.log("QJuryDispute deployed at:", address(disputeContract));
        
        console.log("Deploying QJuryReward...");
        QJuryReward rewardContract = new QJuryReward(
            address(registry),
            address(voteContract),
            address(disputeContract)
        );
        console.log("QJuryReward deployed at:", address(rewardContract));
        
        vm.stopBroadcast();
        
        // Save deployment addresses
        string memory deploymentInfo = string(abi.encodePacked(
            "QJury Deployment Complete\n",
            "========================\n",
            "Network: ", vm.toString(block.chainid), "\n",
            "Deployer: ", vm.toString(deployer), "\n",
            "QJuryRegistry: ", vm.toString(address(registry)), "\n",
            "QuantumRandomOracle: ", vm.toString(address(quantumOracle)), "\n",
            "QJuryVote: ", vm.toString(address(voteContract)), "\n",
            "QJuryDispute: ", vm.toString(address(disputeContract)), "\n",
            "QJuryReward: ", vm.toString(address(rewardContract)), "\n"
        ));
        
        console.log(deploymentInfo);
        
        // Write deployment info to file
        vm.writeFile("deployment.txt", deploymentInfo);
        
        console.log("Deployment addresses saved to deployment.txt");
        console.log("Next steps:");
        console.log("1. Update your .env file with the contract addresses");
        console.log("2. Authorize oracle operators in QuantumRandomOracle");
        console.log("3. Start the quantum oracle service");
    }
} 