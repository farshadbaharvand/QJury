// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

import {MockQRandomOracle} from "../contracts/MockQRandomOracle.sol";
import {QJuryRegistry} from "../contracts/QJuryRegistry.sol";
import {QJuryVote} from "../contracts/QJuryVote.sol";
import {QJuryReward} from "../contracts/QJuryReward.sol";
import {QJuryDispute} from "../contracts/QJuryDispute.sol";

contract DeployQJury is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy Mock Oracle (no constructor)
        MockQRandomOracle oracle = new MockQRandomOracle();

        // Step 2: Deploy Registry (no constructor)
        QJuryRegistry registry = new QJuryRegistry();

        // Step 3: Deploy Vote (needs registry)
        QJuryVote vote = new QJuryVote(address(registry));

        // Step 4: Deploy Dispute (needs registry, vote, oracle)
        QJuryDispute dispute = new QJuryDispute(
            address(registry),
            address(vote),
            address(oracle)
        );

        // Step 5: Deploy Reward (needs registry, vote, dispute)
        QJuryReward reward = new QJuryReward(
            address(registry),
            address(vote),
            address(dispute)
        );

        vm.stopBroadcast();

        console.log("Deployment Complete:");
        console.log("MockQRandomOracle:", address(oracle));
        console.log("QJuryRegistry:", address(registry));
        console.log("QJuryVote:", address(vote));
        console.log("QJuryDispute:", address(dispute));
        console.log("QJuryReward:", address(reward));
    }
}
