// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/QJuryRegistry.sol";
import "../contracts/QJuryVote.sol";
import "../contracts/QJuryDispute.sol";
import "../contracts/QJuryReward.sol";
import "../contracts/QuantumRandomOracle.sol";
import "../contracts/MockQRandomOracle.sol";

contract QuantumIntegrationTest is Test {
    // Event declarations for testing
    event RandomnessRequested(uint256 indexed requestId, uint256 timestamp);
    event RandomnessFulfilled(uint256 indexed requestId, uint256 randomValue, address indexed oracle);
    event OracleAuthorized(address indexed oracle, bool authorized);
    QJuryRegistry public registry;
    QJuryVote public voteContract;
    QJuryDispute public disputeContract;
    QJuryReward public rewardContract;
    QuantumRandomOracle public quantumOracle;
    MockQRandomOracle public mockOracle;
    
    // Test accounts
    address public owner = makeAddr("owner");
    address public oracleOperator = makeAddr("oracleOperator");
    address public creator = makeAddr("creator");
    address public juror1 = makeAddr("juror1");
    address public juror2 = makeAddr("juror2");
    address public juror3 = makeAddr("juror3");
    address public juror4 = makeAddr("juror4");
    address public juror5 = makeAddr("juror5");
    address public juror6 = makeAddr("juror6");
    address public juror7 = makeAddr("juror7");
    address public juror8 = makeAddr("juror8");
    address public juror9 = makeAddr("juror9");
    address public juror10 = makeAddr("juror10");
    address public juror11 = makeAddr("juror11");
    address public juror12 = makeAddr("juror12");
    
    address[] public jurors;
    
    function setUp() public {
        // Deploy contracts
        registry = new QJuryRegistry();
        quantumOracle = new QuantumRandomOracle();
        mockOracle = new MockQRandomOracle();
        voteContract = new QJuryVote(address(registry));
        disputeContract = new QJuryDispute(address(registry), address(voteContract), address(quantumOracle));
        rewardContract = new QJuryReward(address(registry), address(voteContract), address(disputeContract));
        
        // Set up juror array
        jurors = [juror1, juror2, juror3, juror4, juror5, juror6, juror7, juror8, juror9, juror10, juror11, juror12];
        
        // Fund accounts
        vm.deal(owner, 100 ether);
        vm.deal(oracleOperator, 10 ether);
        vm.deal(creator, 10 ether);
        for (uint256 i = 0; i < jurors.length; i++) {
            vm.deal(jurors[i], 10 ether);
        }
        
        // Fund reward contract
        vm.deal(address(rewardContract), 10 ether);
        
        // Authorize oracle operator
        vm.startPrank(owner);
        quantumOracle.setOracleAuthorization(oracleOperator, true);
        vm.stopPrank();
    }
    
    function testQuantumOracleDeployment() public {
        console.log("=== Testing Quantum Oracle Deployment ===");
        
        assertEq(quantumOracle.owner(), owner);
        assertTrue(quantumOracle.isAuthorizedOracle(owner));
        assertTrue(quantumOracle.isAuthorizedOracle(oracleOperator));
        assertFalse(quantumOracle.isAuthorizedOracle(address(0x123)));
        
        console.log("Quantum oracle deployed successfully");
    }
    
    function testRandomnessRequestAndFulfillment() public {
        console.log("=== Testing Randomness Request and Fulfillment ===");
        
        // Request randomness
        uint256 requestId = quantumOracle.requestRandomness();
        assertEq(requestId, 1);
        
        // Check request details
        (bool fulfilled, uint256 randomValue, uint256 timestamp) = quantumOracle.getRequestDetails(requestId);
        assertFalse(fulfilled);
        assertEq(randomValue, 0);
        assertGt(timestamp, 0);
        
        // Fulfill with quantum randomness (simulated)
        uint256 quantumRandomValue = 42; // Simulated quantum value
        vm.startPrank(oracleOperator);
        quantumOracle.fulfillRandomness(requestId, quantumRandomValue);
        vm.stopPrank();
        
        // Verify fulfillment
        (fulfilled, randomValue, ) = quantumOracle.getRequestDetails(requestId);
        assertTrue(fulfilled);
        assertEq(randomValue, quantumRandomValue);
        assertTrue(quantumOracle.isRequestFulfilled(requestId));
        
        console.log("Randomness request and fulfillment working correctly");
    }
    
    function testQuantumOracleAuthorization() public {
        console.log("=== Testing Oracle Authorization ===");
        
        address unauthorizedOracle = makeAddr("unauthorized");
        vm.deal(unauthorizedOracle, 1 ether);
        
        // Request randomness
        uint256 requestId = quantumOracle.requestRandomness();
        
        // Try to fulfill with unauthorized oracle
        vm.startPrank(unauthorizedOracle);
        vm.expectRevert("Not authorized oracle");
        quantumOracle.fulfillRandomness(requestId, 42);
        vm.stopPrank();
        
        // Authorize the oracle
        vm.startPrank(owner);
        quantumOracle.setOracleAuthorization(unauthorizedOracle, true);
        vm.stopPrank();
        
        // Now should be able to fulfill
        vm.startPrank(unauthorizedOracle);
        quantumOracle.fulfillRandomness(requestId, 42);
        vm.stopPrank();
        
        assertTrue(quantumOracle.isRequestFulfilled(requestId));
        
        console.log("Authorization controls working correctly");
    }
    
    function testQuantumOracleExpiry() public {
        console.log("=== Testing Oracle Request Expiry ===");
        
        uint256 requestId = quantumOracle.requestRandomness();
        
        // Fast forward past expiry time
        vm.warp(block.timestamp + quantumOracle.MAX_FULFILLMENT_DELAY() + 1);
        
        // Try to fulfill expired request
        vm.startPrank(oracleOperator);
        vm.expectRevert("Request expired");
        quantumOracle.fulfillRandomness(requestId, 42);
        vm.stopPrank();
        
        console.log("Request expiry working correctly");
    }
    
    function testFullQuantumWorkflow() public {
        console.log("=== Testing Full Quantum Workflow ===");
        
        // Step 1: Register jurors
        _registerJurors();
        
        // Step 2: Create dispute
        uint256 disputeId = _createDispute();
        
        // Step 3: Simulate quantum randomness fulfillment
        _fulfillQuantumRandomness(disputeId);
        
        // Step 4: Assign jurors
        _assignJurors(disputeId);
        
        // Step 5: Vote and resolve
        _completeVotingAndResolution(disputeId);
        
        console.log("Full quantum workflow completed successfully");
    }
    
    function testQuantumOracleEvents() public {
        console.log("=== Testing Quantum Oracle Events ===");
        
        // Test RandomnessRequested event
        vm.expectEmit(true, false, false, true);
        emit RandomnessRequested(1, block.timestamp);
        uint256 requestId = quantumOracle.requestRandomness();
        
        // Test RandomnessFulfilled event
        vm.expectEmit(true, false, true, true);
        emit RandomnessFulfilled(requestId, 42, oracleOperator);
        vm.startPrank(oracleOperator);
        quantumOracle.fulfillRandomness(requestId, 42);
        vm.stopPrank();
        
        // Test OracleAuthorized event
        address newOracle = makeAddr("newOracle");
        vm.expectEmit(true, true, false, true);
        emit OracleAuthorized(newOracle, true);
        vm.startPrank(owner);
        quantumOracle.setOracleAuthorization(newOracle, true);
        vm.stopPrank();
        
        console.log("All quantum oracle events working correctly");
    }
    
    function testDisputeContractQuantumIntegration() public {
        console.log("=== Testing Dispute Contract Quantum Integration ===");
        
        // Register jurors
        _registerJurors();
        
        // Create dispute (this will request quantum randomness)
        vm.startPrank(creator);
        uint256 disputeId = disputeContract.createDispute{value: 0.01 ether}("Test dispute");
        vm.stopPrank();
        
        // Check that randomness was requested
        QJuryDispute.Dispute memory dispute = disputeContract.getDispute(disputeId);
        assertEq(dispute.randomnessRequestId, 1);
        assertFalse(dispute.randomnessFulfilled);
        
        // Fulfill the randomness request
        _fulfillQuantumRandomness(disputeId);
        
        // Now should be able to assign jurors
        assertTrue(disputeContract.canAssignJurors(disputeId));
        
        console.log("Dispute contract quantum integration working correctly");
    }
    
    function testFrontendIntegrationFunctions() public {
        console.log("=== Testing Frontend Integration Functions ===");
        
        // Register jurors and create dispute
        _registerJurors();
        uint256 disputeId = _createDispute();
        
        // Test getDisputeWithDetails
        (
            QJuryDispute.Dispute memory dispute,
            bool canAssignJurors,
            uint256 eligibleJurorCount
        ) = disputeContract.getDisputeWithDetails(disputeId);
        
        assertEq(dispute.id, disputeId);
        assertFalse(canAssignJurors); // Not fulfilled yet
        assertEq(eligibleJurorCount, jurors.length);
        
        // Test getTimeUntilExpiry
        uint256 timeUntilExpiry = disputeContract.getTimeUntilExpiry(disputeId);
        assertGt(timeUntilExpiry, 0);
        
        // Test getDisputesByCreator
        uint256[] memory creatorDisputes = disputeContract.getDisputesByCreator(creator);
        assertEq(creatorDisputes.length, 1);
        assertEq(creatorDisputes[0], disputeId);
        
        // Test getDisputesByStatus
        uint256[] memory createdDisputes = disputeContract.getDisputesByStatus(QJuryDispute.DisputeStatus.Created);
        assertEq(createdDisputes.length, 1);
        assertEq(createdDisputes[0], disputeId);
        
        // Test metadata update
        vm.startPrank(creator);
        disputeContract.updateDisputeMetadata(disputeId, 12345);
        vm.stopPrank();
        
        dispute = disputeContract.getDispute(disputeId);
        assertEq(dispute.metadata, 12345);
        
        console.log("Frontend integration functions working correctly");
    }
    
    function testQuantumOracleEdgeCases() public {
        console.log("=== Testing Quantum Oracle Edge Cases ===");
        
        // Test double fulfillment
        uint256 requestId = quantumOracle.requestRandomness();
        vm.startPrank(oracleOperator);
        quantumOracle.fulfillRandomness(requestId, 42);
        vm.expectRevert("Request already fulfilled");
        quantumOracle.fulfillRandomness(requestId, 43);
        vm.stopPrank();
        
        // Test non-existent request
        vm.startPrank(oracleOperator);
        vm.expectRevert("Request does not exist");
        quantumOracle.fulfillRandomness(999, 42);
        vm.stopPrank();
        
        // Test deauthorization
        vm.startPrank(owner);
        quantumOracle.setOracleAuthorization(oracleOperator, false);
        vm.stopPrank();
        
        uint256 newRequestId = quantumOracle.requestRandomness();
        vm.startPrank(oracleOperator);
        vm.expectRevert("Not authorized oracle");
        quantumOracle.fulfillRandomness(newRequestId, 42);
        vm.stopPrank();
        
        console.log("Edge cases handled correctly");
    }
    
    // Helper functions
    function _registerJurors() internal {
        for (uint256 i = 0; i < jurors.length; i++) {
            vm.startPrank(jurors[i]);
            registry.registerJuror{value: 0.1 ether}();
            vm.stopPrank();
        }
    }
    
    function _createDispute() internal returns (uint256) {
        vm.startPrank(creator);
        uint256 disputeId = disputeContract.createDispute{value: 0.01 ether}("Test dispute");
        vm.stopPrank();
        return disputeId;
    }
    
    function _fulfillQuantumRandomness(uint256 disputeId) internal {
        QJuryDispute.Dispute memory dispute = disputeContract.getDispute(disputeId);
        uint256 requestId = dispute.randomnessRequestId;
        
        // Simulate quantum randomness (in production, this would come from ANU API)
        uint256 quantumRandomValue = uint256(keccak256(abi.encodePacked(block.timestamp, requestId))) % 256;
        
        vm.startPrank(oracleOperator);
        quantumOracle.fulfillRandomness(requestId, quantumRandomValue);
        vm.stopPrank();
    }
    
    function _assignJurors(uint256 disputeId) internal {
        disputeContract.assignJurors(disputeId);
    }
    
    function _completeVotingAndResolution(uint256 disputeId) internal {
        // Get assigned jurors
        address[] memory assignedJurors = disputeContract.getAssignedJurors(disputeId);
        
        // Jurors vote (simplified - all vote support)
        for (uint256 i = 0; i < assignedJurors.length; i++) {
            vm.startPrank(assignedJurors[i]);
            voteContract.castVote(disputeId, QJuryVote.VoteChoice.Support);
            vm.stopPrank();
        }
        
        // Close voting
        voteContract.closeVoting(disputeId);
        
        // Resolve dispute
        disputeContract.resolveDispute(disputeId);
        
        // Distribute rewards
        rewardContract.distributeRewards(disputeId);
    }
} 