// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/QJuryRegistry.sol";
import "../contracts/QJuryVote.sol";
import "../contracts/QJuryDispute.sol";
import "../contracts/QJuryReward.sol";
import "../contracts/QuantumRandomOracle.sol";
import "../contracts/MockQRandomOracle.sol";

/**
 * @title QJuryQuantumSystemTest
 * @dev Comprehensive test suite for QJury system with quantum randomness
 */
contract QJuryQuantumSystemTest is Test {
    // Contracts
    QJuryRegistry public registry;
    QJuryVote public voteContract;
    QJuryDispute public disputeContract;
    QJuryReward public rewardContract;
    QuantumRandomOracle public quantumOracle;
    MockQRandomOracle public mockOracle;
    
    // Test accounts
    address public owner;
    address public oracle;
    address public creator;
    address public juror1;
    address public juror2;
    address public juror3;
    address public juror4;
    address public juror5;
    address[] public jurors;
    
    // Constants
    uint256 constant MINIMUM_STAKE = 0.1 ether;
    uint256 constant DISPUTE_FEE = 0.01 ether;
    uint256 constant JURORS_PER_DISPUTE = 10;
    
    // Events to test
    event DisputeCreated(uint256 indexed disputeId, address indexed creator, string description, uint256 fee);
    event RandomnessRequested(uint256 indexed disputeId, uint256 randomnessRequestId);
    event JurorsAssigned(uint256 indexed disputeId, address[] assignedJurors);
    event QuantumRandomnessReceived(uint256 indexed disputeId, uint256 randomValue, uint256 timestamp);
    event DisputeStatusChanged(uint256 indexed disputeId, QJuryDispute.DisputeStatus indexed oldStatus, QJuryDispute.DisputeStatus indexed newStatus);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RandomnessFulfilled(uint256 indexed requestId, uint256 randomValue, address indexed oracle, uint256 timestamp);
    
    function setUp() public {
        // Setup test accounts
        owner = address(this);
        oracle = makeAddr("oracle");
        creator = makeAddr("creator");
        juror1 = makeAddr("juror1");
        juror2 = makeAddr("juror2");
        juror3 = makeAddr("juror3");
        juror4 = makeAddr("juror4");
        juror5 = makeAddr("juror5");
        
        // Create array of jurors for bulk operations
        jurors = [juror1, juror2, juror3, juror4, juror5];
        
        // Add more jurors to meet minimum requirement
        for (uint256 i = 6; i <= 15; i++) {
            jurors.push(makeAddr(string(abi.encodePacked("juror", vm.toString(i)))));
        }
        
        // Deploy contracts
        registry = new QJuryRegistry();
        voteContract = new QJuryVote(address(registry));
        quantumOracle = new QuantumRandomOracle();
        mockOracle = new MockQRandomOracle();
        
        disputeContract = new QJuryDispute(
            address(registry),
            address(voteContract),
            address(quantumOracle)
        );
        
        rewardContract = new QJuryReward(
            address(registry),
            address(voteContract),
            address(disputeContract)
        );
        
        // Setup oracle authorization
        quantumOracle.setOracleAuthorization(oracle, true);
        
        // Fund test accounts
        vm.deal(creator, 10 ether);
        for (uint256 i = 0; i < jurors.length; i++) {
            vm.deal(jurors[i], 10 ether);
        }
    }
    
    function testQuantumOracleDeployment() public {
        assertEq(quantumOracle.owner(), owner);
        assertTrue(quantumOracle.authorizedOracles(owner));
        assertTrue(quantumOracle.authorizedOracles(oracle));
        assertEq(quantumOracle.getTotalRequests(), 0);
    }
    
    function testOracleAuthorization() public {
        address newOracle = makeAddr("newOracle");
        
        // Only owner can authorize
        vm.prank(oracle);
        vm.expectRevert("Not the contract owner");
        quantumOracle.setOracleAuthorization(newOracle, true);
        
        // Owner can authorize
        quantumOracle.setOracleAuthorization(newOracle, true);
        assertTrue(quantumOracle.authorizedOracles(newOracle));
        
        // Owner can deauthorize
        quantumOracle.setOracleAuthorization(newOracle, false);
        assertFalse(quantumOracle.authorizedOracles(newOracle));
    }
    
    function testOwnershipTransfer() public {
        address newOwner = makeAddr("newOwner");
        
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(owner, newOwner);
        
        quantumOracle.transferOwnership(newOwner);
        assertEq(quantumOracle.owner(), newOwner);
    }
    
    function testRandomnessRequest() public {
        uint256 requestId = quantumOracle.requestRandomness();
        
        assertEq(requestId, 1);
        assertEq(quantumOracle.getTotalRequests(), 1);
        assertFalse(quantumOracle.isRequestFulfilled(requestId));
        
        QuantumRandomOracle.RandomnessRequest memory request = quantumOracle.getRequest(requestId);
        assertEq(request.requestId, requestId);
        assertEq(request.requester, address(this));
        assertFalse(request.fulfilled);
        assertEq(request.randomValue, 0);
    }
    
    function testRandomnessFulfillment() public {
        uint256 requestId = quantumOracle.requestRandomness();
        uint256 randomValue = 12345678901234567890;
        
        // Only authorized oracle can fulfill
        vm.prank(makeAddr("unauthorized"));
        vm.expectRevert("Not an authorized oracle");
        quantumOracle.fulfillRandomness(requestId, randomValue);
        
        // Need enough block confirmations
        vm.prank(oracle);
        vm.expectRevert("Not enough block confirmations");
        quantumOracle.fulfillRandomness(requestId, randomValue);
        
        // Advance blocks
        vm.roll(block.number + 3);
        
        // Authorized oracle can fulfill
        vm.prank(oracle);
        vm.expectEmit(true, false, false, true);
        emit RandomnessFulfilled(requestId, randomValue, oracle, block.timestamp);
        
        quantumOracle.fulfillRandomness(requestId, randomValue);
        
        assertTrue(quantumOracle.isRequestFulfilled(requestId));
        assertEq(quantumOracle.getRandomValue(requestId), randomValue);
    }
    
    function testRegisterJurors() public {
        // Register multiple jurors
        for (uint256 i = 0; i < jurors.length; i++) {
            vm.prank(jurors[i]);
            registry.registerJuror{value: MINIMUM_STAKE}();
            
            QJuryRegistry.Juror memory jurorInfo = registry.getJuror(jurors[i]);
            assertTrue(jurorInfo.isRegistered);
            assertEq(jurorInfo.stakedAmount, MINIMUM_STAKE);
            assertFalse(jurorInfo.isSlashed);
        }
        
        address[] memory eligibleJurors = registry.getEligibleJurors();
        assertEq(eligibleJurors.length, jurors.length);
    }
    
    function testCreateDisputeWithQuantumRandomness() public {
        // Register jurors first
        for (uint256 i = 0; i < jurors.length; i++) {
            vm.prank(jurors[i]);
            registry.registerJuror{value: MINIMUM_STAKE}();
        }
        
        vm.prank(creator);
        vm.expectEmit(true, true, false, true);
        emit DisputeCreated(1, creator, "Test dispute", DISPUTE_FEE);
        
        vm.expectEmit(true, false, false, true);
        emit RandomnessRequested(1, 1);
        
        uint256 disputeId = disputeContract.createDispute{value: DISPUTE_FEE}("Test dispute");
        
        assertEq(disputeId, 1);
        
        QJuryDispute.Dispute memory dispute = disputeContract.getDispute(disputeId);
        assertEq(dispute.id, disputeId);
        assertEq(dispute.creator, creator);
        assertEq(uint256(dispute.status), uint256(QJuryDispute.DisputeStatus.Created));
        assertEq(dispute.randomnessRequestId, 1);
        assertFalse(dispute.randomnessFulfilled);
    }
    
    function testCompleteDisputeFlow() public {
        // Register jurors
        for (uint256 i = 0; i < jurors.length; i++) {
            vm.prank(jurors[i]);
            registry.registerJuror{value: MINIMUM_STAKE}();
        }
        
        // Create dispute
        vm.prank(creator);
        uint256 disputeId = disputeContract.createDispute{value: DISPUTE_FEE}("Test dispute");
        
        // Fulfill randomness
        uint256 randomValue = 987654321098765432109876543210;
        vm.roll(block.number + 3);
        
        vm.prank(oracle);
        quantumOracle.fulfillRandomness(1, randomValue);
        
        // Assign jurors
        vm.expectEmit(true, false, false, true);
        emit QuantumRandomnessReceived(disputeId, randomValue, block.timestamp);
        
        vm.expectEmit(true, false, false, false);
        emit DisputeStatusChanged(disputeId, QJuryDispute.DisputeStatus.Created, QJuryDispute.DisputeStatus.JurorsAssigned);
        
        disputeContract.assignJurors(disputeId);
        
        QJuryDispute.Dispute memory dispute = disputeContract.getDispute(disputeId);
        assertEq(uint256(dispute.status), uint256(QJuryDispute.DisputeStatus.VotingStarted));
        assertTrue(dispute.randomnessFulfilled);
        assertEq(dispute.assignedJurors.length, JURORS_PER_DISPUTE);
        
        // Verify voting started
        (address[] memory assignedJurors, , , , , , ) = voteContract.getDisputeVoting(disputeId);
        assertEq(assignedJurors.length, JURORS_PER_DISPUTE);
    }
    
    function testJurorSelection() public {
        // Register jurors
        for (uint256 i = 0; i < jurors.length; i++) {
            vm.prank(jurors[i]);
            registry.registerJuror{value: MINIMUM_STAKE}();
        }
        
        // Create and fulfill dispute
        vm.prank(creator);
        uint256 disputeId = disputeContract.createDispute{value: DISPUTE_FEE}("Test dispute");
        
        vm.roll(block.number + 3);
        vm.prank(oracle);
        quantumOracle.fulfillRandomness(1, 12345);
        
        disputeContract.assignJurors(disputeId);
        
        address[] memory selectedJurors = disputeContract.getAssignedJurors(disputeId);
        assertEq(selectedJurors.length, JURORS_PER_DISPUTE);
        
        // Verify no duplicates in selected jurors
        for (uint256 i = 0; i < selectedJurors.length; i++) {
            for (uint256 j = i + 1; j < selectedJurors.length; j++) {
                assertTrue(selectedJurors[i] != selectedJurors[j]);
            }
        }
        
        // Verify all selected jurors are eligible
        for (uint256 i = 0; i < selectedJurors.length; i++) {
            assertTrue(registry.isEligibleJuror(selectedJurors[i]));
        }
    }
    
    function testVotingProcess() public {
        // Setup dispute with assigned jurors
        for (uint256 i = 0; i < jurors.length; i++) {
            vm.prank(jurors[i]);
            registry.registerJuror{value: MINIMUM_STAKE}();
        }
        
        vm.prank(creator);
        uint256 disputeId = disputeContract.createDispute{value: DISPUTE_FEE}("Test dispute");
        
        vm.roll(block.number + 3);
        vm.prank(oracle);
        quantumOracle.fulfillRandomness(1, 12345);
        
        disputeContract.assignJurors(disputeId);
        
        address[] memory selectedJurors = disputeContract.getAssignedJurors(disputeId);
        
        // Cast votes
        for (uint256 i = 0; i < selectedJurors.length; i++) {
            vm.prank(selectedJurors[i]);
            QJuryVote.VoteChoice choice = i < 6 ? QJuryVote.VoteChoice.Support : QJuryVote.VoteChoice.Against;
            voteContract.castVote(disputeId, choice);
        }
        
        // Close voting
        voteContract.closeVoting(disputeId);
        
        (, , bool isVotingClosed, QJuryVote.VoteChoice majorityChoice, uint256 supportVotes, uint256 againstVotes, ) = 
            voteContract.getDisputeVoting(disputeId);
        
        assertTrue(isVotingClosed);
        assertEq(uint256(majorityChoice), uint256(QJuryVote.VoteChoice.Support));
        assertEq(supportVotes, 6);
        assertEq(againstVotes, 4);
    }
    
    function testDisputeResolution() public {
        // Complete dispute flow up to voting
        for (uint256 i = 0; i < jurors.length; i++) {
            vm.prank(jurors[i]);
            registry.registerJuror{value: MINIMUM_STAKE}();
        }
        
        vm.prank(creator);
        uint256 disputeId = disputeContract.createDispute{value: DISPUTE_FEE}("Test dispute");
        
        vm.roll(block.number + 3);
        vm.prank(oracle);
        quantumOracle.fulfillRandomness(1, 12345);
        
        disputeContract.assignJurors(disputeId);
        
        address[] memory selectedJurors = disputeContract.getAssignedJurors(disputeId);
        
        // Cast votes and close voting
        for (uint256 i = 0; i < selectedJurors.length; i++) {
            vm.prank(selectedJurors[i]);
            voteContract.castVote(disputeId, QJuryVote.VoteChoice.Support);
        }
        
        voteContract.closeVoting(disputeId);
        
        // Resolve dispute
        vm.expectEmit(true, false, false, false);
        emit DisputeStatusChanged(disputeId, QJuryDispute.DisputeStatus.VotingStarted, QJuryDispute.DisputeStatus.Resolved);
        
        disputeContract.resolveDispute(disputeId);
        
        QJuryDispute.Dispute memory dispute = disputeContract.getDispute(disputeId);
        assertEq(uint256(dispute.status), uint256(QJuryDispute.DisputeStatus.Resolved));
    }
    
    function testRewardDistribution() public {
        // Complete dispute flow
        for (uint256 i = 0; i < jurors.length; i++) {
            vm.prank(jurors[i]);
            registry.registerJuror{value: MINIMUM_STAKE}();
        }
        
        vm.prank(creator);
        uint256 disputeId = disputeContract.createDispute{value: DISPUTE_FEE}("Test dispute");
        
        vm.roll(block.number + 3);
        vm.prank(oracle);
        quantumOracle.fulfillRandomness(1, 12345);
        
        disputeContract.assignJurors(disputeId);
        
        address[] memory selectedJurors = disputeContract.getAssignedJurors(disputeId);
        
        // Cast votes (60% support, 40% against)
        for (uint256 i = 0; i < selectedJurors.length; i++) {
            vm.prank(selectedJurors[i]);
            QJuryVote.VoteChoice choice = i < 6 ? QJuryVote.VoteChoice.Support : QJuryVote.VoteChoice.Against;
            voteContract.castVote(disputeId, choice);
        }
        
        voteContract.closeVoting(disputeId);
        disputeContract.resolveDispute(disputeId);
        
        // Fund reward contract
        vm.deal(address(rewardContract), 1 ether);
        
        // Distribute rewards
        rewardContract.distributeRewards(disputeId);
        
        QJuryReward.RewardDistribution memory distribution = rewardContract.getRewardDistribution(disputeId);
        assertTrue(distribution.isDistributed);
        assertEq(distribution.correctVoters.length, 6);
        assertEq(distribution.incorrectVoters.length, 4);
    }
    
    function testFrontendIntegrationViews() public {
        // Register jurors and create dispute
        for (uint256 i = 0; i < jurors.length; i++) {
            vm.prank(jurors[i]);
            registry.registerJuror{value: MINIMUM_STAKE}();
        }
        
        vm.prank(creator);
        uint256 disputeId = disputeContract.createDispute{value: DISPUTE_FEE}("Test dispute");
        
        // Test contract address getters
        assertEq(disputeContract.getQuantumOracleAddress(), address(quantumOracle));
        assertEq(disputeContract.getRegistryAddress(), address(registry));
        assertEq(disputeContract.getVoteContractAddress(), address(voteContract));
        
        // Test dispute summary
        (uint256 id, address disputeCreator, QJuryDispute.DisputeStatus status, uint256 jurorsAssigned, bool randomnessFulfilled, uint256 createdAt) = 
            disputeContract.getDisputeSummary(disputeId);
        
        assertEq(id, disputeId);
        assertEq(disputeCreator, creator);
        assertEq(uint256(status), uint256(QJuryDispute.DisputeStatus.Created));
        assertEq(jurorsAssigned, 0); // Not assigned yet
        assertFalse(randomnessFulfilled);
        assertGt(createdAt, 0);
        
        // Test disputes by creator
        uint256[] memory creatorDisputes = disputeContract.getDisputesByCreator(creator);
        assertEq(creatorDisputes.length, 1);
        assertEq(creatorDisputes[0], disputeId);
        
        // Test recent disputes
        uint256[] memory recentDisputes = disputeContract.getRecentDisputes(5);
        assertEq(recentDisputes.length, 1);
        assertEq(recentDisputes[0], disputeId);
        
        // Test metadata (basic check - actual JSON parsing would need more complex testing)
        string memory metadata = disputeContract.getDisputeMetadata(disputeId);
        assertTrue(bytes(metadata).length > 0);
    }
    
    function testQuantumRandomnessExpiry() public {
        uint256 requestId = quantumOracle.requestRandomness();
        
        // Fast forward past timeout
        vm.warp(block.timestamp + 2 hours);
        
        assertTrue(quantumOracle.isRequestExpired(requestId));
        
        // Cancel expired request
        quantumOracle.cancelExpiredRequest(requestId);
        
        assertTrue(quantumOracle.isRequestFulfilled(requestId));
        assertGt(quantumOracle.getRandomValue(requestId), 0);
    }
    
    function testPendingRequestsTracking() public {
        // No pending requests initially
        uint256[] memory pending = quantumOracle.getPendingRequests();
        assertEq(pending.length, 0);
        
        // Create requests
        uint256 req1 = quantumOracle.requestRandomness();
        uint256 req2 = quantumOracle.requestRandomness();
        uint256 req3 = quantumOracle.requestRandomness();
        
        // All should be pending
        pending = quantumOracle.getPendingRequests();
        assertEq(pending.length, 3);
        
        // Fulfill one
        vm.roll(block.number + 3);
        vm.prank(oracle);
        quantumOracle.fulfillRandomness(req1, 12345);
        
        // Should have 2 pending
        pending = quantumOracle.getPendingRequests();
        assertEq(pending.length, 2);
        
        // Expire one
        vm.warp(block.timestamp + 2 hours);
        quantumOracle.cancelExpiredRequest(req2);
        
        // Should have 1 pending (req3)
        pending = quantumOracle.getPendingRequests();
        assertEq(pending.length, 1);
        assertEq(pending[0], req3);
    }
    
    function testFailInsufficientDisputeFee() public {
        vm.prank(creator);
        disputeContract.createDispute{value: 0.005 ether}("Test dispute");
    }
    
    function testFailAssignJurorsWithoutRandomness() public {
        vm.prank(creator);
        uint256 disputeId = disputeContract.createDispute{value: DISPUTE_FEE}("Test dispute");
        
        disputeContract.assignJurors(disputeId);
    }
    
    function testFailUnauthorizedRandomnessFulfillment() public {
        uint256 requestId = quantumOracle.requestRandomness();
        vm.roll(block.number + 3);
        
        vm.prank(makeAddr("unauthorized"));
        quantumOracle.fulfillRandomness(requestId, 12345);
    }
    
    function testFailInsufficientEligibleJurors() public {
        // Register only 5 jurors (need 10)
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(jurors[i]);
            registry.registerJuror{value: MINIMUM_STAKE}();
        }
        
        vm.prank(creator);
        uint256 disputeId = disputeContract.createDispute{value: DISPUTE_FEE}("Test dispute");
        
        vm.roll(block.number + 3);
        vm.prank(oracle);
        quantumOracle.fulfillRandomness(1, 12345);
        
        disputeContract.assignJurors(disputeId);
    }
    
    function testFuzzRandomnessValues(uint256 randomValue) public {
        vm.assume(randomValue > 0);
        
        // Register jurors
        for (uint256 i = 0; i < jurors.length; i++) {
            vm.prank(jurors[i]);
            registry.registerJuror{value: MINIMUM_STAKE}();
        }
        
        // Create dispute
        vm.prank(creator);
        uint256 disputeId = disputeContract.createDispute{value: DISPUTE_FEE}("Test dispute");
        
        // Fulfill with fuzz value
        vm.roll(block.number + 3);
        vm.prank(oracle);
        quantumOracle.fulfillRandomness(1, randomValue);
        
        // Assign jurors
        disputeContract.assignJurors(disputeId);
        
        // Verify selection worked
        address[] memory selectedJurors = disputeContract.getAssignedJurors(disputeId);
        assertEq(selectedJurors.length, JURORS_PER_DISPUTE);
        
        // Verify no duplicates
        for (uint256 i = 0; i < selectedJurors.length; i++) {
            for (uint256 j = i + 1; j < selectedJurors.length; j++) {
                assertTrue(selectedJurors[i] != selectedJurors[j]);
            }
        }
    }
}