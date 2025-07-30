// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/QJuryRegistry.sol";
import "../contracts/QJuryVote.sol";
import "../contracts/QJuryDispute.sol";
import "../contracts/QJuryReward.sol";
import "../contracts/MockQRandomOracle.sol";

contract QJurySystemTest is Test {
    QJuryRegistry public registry;
    QJuryVote public voteContract;
    QJuryDispute public disputeContract;
    QJuryReward public rewardContract;
    MockQRandomOracle public randomOracle;
    
    // Test accounts
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
    address public disputer = makeAddr("disputer");
    
    address[] public jurors;
    
    function setUp() public {
        // Deploy contracts
        registry = new QJuryRegistry();
        randomOracle = new MockQRandomOracle();
        voteContract = new QJuryVote(address(registry));
        disputeContract = new QJuryDispute(address(registry), address(voteContract), address(randomOracle));
        rewardContract = new QJuryReward(address(registry), address(voteContract), address(disputeContract));
        
        // Set up juror array
        jurors = [juror1, juror2, juror3, juror4, juror5, juror6, juror7, juror8, juror9, juror10, juror11, juror12];
        
        // Fund accounts
        vm.deal(creator, 100 ether);
        vm.deal(disputer, 10 ether);
        for (uint256 i = 0; i < jurors.length; i++) {
            vm.deal(jurors[i], 10 ether);
        }
        
        // Fund reward contract
        vm.deal(address(rewardContract), 10 ether);
    }
    
    function testFullQJuryWorkflow() public {
        // Step 1: Register jurors
        _registerJurors();
        
        // Step 2: Create a dispute
        uint256 disputeId = _createDispute();
        
        // Step 3: Mock randomness and assign jurors
        _assignJurors(disputeId);
        
        // Step 4: Jurors vote
        _jurorsVote(disputeId);
        
        // Step 5: Close voting
        _closeVoting(disputeId);
        
        // Step 6: Resolve dispute
        _resolveDispute(disputeId);
        
        // Step 7: Distribute rewards
        _distributeRewards(disputeId);
        
        // Step 8: Verify final state
        _verifyFinalState(disputeId);
    }
    
    function _registerJurors() internal {
        console.log("=== Registering Jurors ===");
        
        for (uint256 i = 0; i < jurors.length; i++) {
            vm.startPrank(jurors[i]);
            registry.registerJuror{value: 0.1 ether}();
            vm.stopPrank();
            
            // Verify registration
            QJuryRegistry.Juror memory juror = registry.getJuror(jurors[i]);
            assertEq(juror.isRegistered, true);
            assertEq(juror.stakedAmount, 0.1 ether);
            assertEq(juror.isSlashed, false);
        }
        
        assertEq(registry.totalRegisteredJurors(), jurors.length);
        console.log("Registered", jurors.length, "jurors");
    }
    
    function _createDispute() internal returns (uint256) {
        console.log("=== Creating Dispute ===");
        
        vm.startPrank(disputer);
        uint256 disputeId = disputeContract.createDispute{value: 0.01 ether}("Test dispute for contract violation");
        vm.stopPrank();
        
        QJuryDispute.Dispute memory dispute = disputeContract.getDispute(disputeId);
        assertEq(dispute.creator, disputer);
        assertEq(dispute.fee, 0.01 ether);
        assertEq(uint256(dispute.status), uint256(QJuryDispute.DisputeStatus.Created));
        
        console.log("Created dispute with ID:", disputeId);
        return disputeId;
    }
    
    function _assignJurors(uint256 disputeId) internal {
        console.log("=== Assigning Jurors ===");
        
        QJuryDispute.Dispute memory dispute = disputeContract.getDispute(disputeId);
        uint256 requestId = dispute.randomnessRequestId;
        
        // Mock the randomness
        uint256 mockRandomValue = 12345678901234567890123456789012345678901234567890123456789012345678;
        randomOracle.setRandomValue(requestId, mockRandomValue);
        
        // Assign jurors
        disputeContract.assignJurors(disputeId);
        
        // Verify assignment
        address[] memory assignedJurors = disputeContract.getAssignedJurors(disputeId);
        assertEq(assignedJurors.length, 10);
        
        console.log("Assigned 10 jurors to dispute");
        
        // Verify all assigned jurors are eligible
        for (uint256 i = 0; i < assignedJurors.length; i++) {
            assertTrue(registry.isEligibleJuror(assignedJurors[i]));
        }
    }
    
    function _jurorsVote(uint256 disputeId) internal {
        console.log("=== Jurors Voting ===");
        
        address[] memory assignedJurors = voteContract.getAssignedJurors(disputeId);
        
        // 7 jurors vote Support, 3 vote Against (Support will be majority)
        for (uint256 i = 0; i < assignedJurors.length; i++) {
            vm.startPrank(assignedJurors[i]);
            
            if (i < 7) {
                voteContract.castVote(disputeId, QJuryVote.VoteChoice.Support);
                console.log("Juror", i, "voted Support");
            } else {
                voteContract.castVote(disputeId, QJuryVote.VoteChoice.Against);
                console.log("Juror", i, "voted Against");
            }
            
            vm.stopPrank();
        }
        
        // Verify votes
        (,,,, uint256 supportVotes, uint256 againstVotes,) = voteContract.getDisputeVoting(disputeId);
        assertEq(supportVotes, 7);
        assertEq(againstVotes, 3);
    }
    
    function _closeVoting(uint256 disputeId) internal {
        console.log("=== Closing Voting ===");
        
        voteContract.closeVoting(disputeId);
        
        // Verify voting is closed and majority determined
        (,, bool isVotingClosed, QJuryVote.VoteChoice majorityChoice,,,) = voteContract.getDisputeVoting(disputeId);
        assertTrue(isVotingClosed);
        assertEq(uint256(majorityChoice), uint256(QJuryVote.VoteChoice.Support));
        
        console.log("Voting closed. Majority choice: Support");
    }
    
    function _resolveDispute(uint256 disputeId) internal {
        console.log("=== Resolving Dispute ===");
        
        disputeContract.resolveDispute(disputeId);
        
        QJuryDispute.Dispute memory dispute = disputeContract.getDispute(disputeId);
        assertEq(uint256(dispute.status), uint256(QJuryDispute.DisputeStatus.Resolved));
        
        console.log("Dispute resolved");
    }
    
    function _distributeRewards(uint256 disputeId) internal {
        console.log("=== Distributing Rewards ===");
        
        address[] memory assignedJurors = voteContract.getAssignedJurors(disputeId);
        uint256[] memory initialBalances = new uint256[](assignedJurors.length);
        uint256[] memory initialStakes = new uint256[](assignedJurors.length);
        
        // Record initial state
        for (uint256 i = 0; i < assignedJurors.length; i++) {
            initialBalances[i] = assignedJurors[i].balance;
            initialStakes[i] = registry.getJuror(assignedJurors[i]).stakedAmount;
        }
        
        rewardContract.distributeRewards(disputeId);
        
        // Verify rewards distribution
        QJuryReward.RewardDistribution memory distribution = rewardContract.getRewardDistribution(disputeId);
        assertTrue(distribution.isDistributed);
        assertEq(distribution.correctVoters.length, 7);
        assertEq(distribution.incorrectVoters.length, 3);
        
        console.log("Rewards distributed to", distribution.correctVoters.length, "correct voters");
        console.log("Slashed", distribution.incorrectVoters.length, "incorrect voters");
        
        // Verify correct voters received rewards
        for (uint256 i = 0; i < distribution.correctVoters.length; i++) {
            address correctVoter = distribution.correctVoters[i];
            assertTrue(correctVoter.balance > initialBalances[_findJurorIndex(assignedJurors, correctVoter)]);
        }
        
        // Verify incorrect voters were slashed
        for (uint256 i = 0; i < distribution.incorrectVoters.length; i++) {
            address incorrectVoter = distribution.incorrectVoters[i];
            uint256 currentStake = registry.getJuror(incorrectVoter).stakedAmount;
            uint256 initialStake = initialStakes[_findJurorIndex(assignedJurors, incorrectVoter)];
            assertTrue(currentStake < initialStake);
        }
    }
    
    function _verifyFinalState(uint256 disputeId) internal {
        console.log("=== Verifying Final State ===");
        
        // Verify dispute is fully resolved
        QJuryDispute.Dispute memory dispute = disputeContract.getDispute(disputeId);
        assertEq(uint256(dispute.status), uint256(QJuryDispute.DisputeStatus.Resolved));
        
        // Verify voting statistics are updated
        address[] memory assignedJurors = voteContract.getAssignedJurors(disputeId);
        for (uint256 i = 0; i < assignedJurors.length; i++) {
            QJuryRegistry.Juror memory juror = registry.getJuror(assignedJurors[i]);
            assertEq(juror.totalVotes, 1);
            
            if (i < 7) {
                // Correct voters
                assertEq(juror.correctVotes, 1);
            } else {
                // Incorrect voters
                assertEq(juror.correctVotes, 0);
            }
        }
        
        console.log("Final state verified successfully");
    }
    
    function _findJurorIndex(address[] memory haystack, address needle) internal pure returns (uint256) {
        for (uint256 i = 0; i < haystack.length; i++) {
            if (haystack[i] == needle) {
                return i;
            }
        }
        revert("Juror not found");
    }
    
    // Additional unit tests
    
    function testJurorRegistration() public {
        vm.startPrank(juror1);
        
        // Test successful registration
        registry.registerJuror{value: 0.1 ether}();
        QJuryRegistry.Juror memory juror = registry.getJuror(juror1);
        assertTrue(juror.isRegistered);
        
        // Test double registration fails
        vm.expectRevert("Already registered");
        registry.registerJuror{value: 0.1 ether}();
        
        vm.stopPrank();
    }
    
    function testInsufficientStake() public {
        vm.startPrank(juror1);
        vm.expectRevert("Insufficient stake");
        registry.registerJuror{value: 0.05 ether}();
        vm.stopPrank();
    }
    
    function testDisputeCreationWithInsufficientFee() public {
        vm.startPrank(disputer);
        vm.expectRevert("Insufficient dispute fee");
        disputeContract.createDispute{value: 0.005 ether}("Test dispute");
        vm.stopPrank();
    }
    
    function testVotingByNonAssignedJuror() public {
        _registerJurors();
        uint256 disputeId = _createDispute();
        _assignJurors(disputeId);
        
        address[] memory assignedJurors = voteContract.getAssignedJurors(disputeId);
        
        // Find a juror that is NOT assigned
        address nonAssignedJuror;
        for (uint256 i = 0; i < jurors.length; i++) {
            bool isAssigned = false;
            for (uint256 j = 0; j < assignedJurors.length; j++) {
                if (jurors[i] == assignedJurors[j]) {
                    isAssigned = true;
                    break;
                }
            }
            if (!isAssigned) {
                nonAssignedJuror = jurors[i];
                break;
            }
        }
        
        require(nonAssignedJuror != address(0), "All jurors were assigned");
        
        // Try to vote with non-assigned juror
        vm.startPrank(nonAssignedJuror);
        vm.expectRevert("Juror not assigned to this dispute");
        voteContract.castVote(disputeId, QJuryVote.VoteChoice.Support);
        vm.stopPrank();
    }
    
    function testDoubleVoting() public {
        _registerJurors();
        uint256 disputeId = _createDispute();
        _assignJurors(disputeId);
        
        address[] memory assignedJurors = voteContract.getAssignedJurors(disputeId);
        
        vm.startPrank(assignedJurors[0]);
        voteContract.castVote(disputeId, QJuryVote.VoteChoice.Support);
        
        vm.expectRevert("Already voted");
        voteContract.castVote(disputeId, QJuryVote.VoteChoice.Against);
        vm.stopPrank();
    }
    
    function testRandomJurorSelection() public {
        _registerJurors();
        
        // Test with different random values produce different selections
        uint256 disputeId1 = _createDispute();
        QJuryDispute.Dispute memory dispute1 = disputeContract.getDispute(disputeId1);
        randomOracle.setRandomValue(dispute1.randomnessRequestId, 123456789);
        disputeContract.assignJurors(disputeId1);
        address[] memory jurors1 = disputeContract.getAssignedJurors(disputeId1);
        
        vm.startPrank(disputer);
        uint256 disputeId2 = disputeContract.createDispute{value: 0.01 ether}("Another test dispute");
        vm.stopPrank();
        
        QJuryDispute.Dispute memory dispute2 = disputeContract.getDispute(disputeId2);
        randomOracle.setRandomValue(dispute2.randomnessRequestId, 987654321);
        disputeContract.assignJurors(disputeId2);
        address[] memory jurors2 = disputeContract.getAssignedJurors(disputeId2);
        
        // Verify different random values produce different selections
        bool different = false;
        for (uint256 i = 0; i < 10; i++) {
            if (jurors1[i] != jurors2[i]) {
                different = true;
                break;
            }
        }
        assertTrue(different, "Different random values should produce different juror selections");
    }
    
    function testStakeWithdrawal() public {
        vm.startPrank(juror1);
        registry.registerJuror{value: 0.2 ether}();
        
        // Test partial withdrawal
        uint256 initialBalance = juror1.balance;
        registry.withdrawStake(0.05 ether);
        assertEq(juror1.balance, initialBalance + 0.05 ether);
        
        // Test withdrawal that would bring below minimum
        vm.expectRevert("Would fall below minimum stake");
        registry.withdrawStake(0.1 ether);
        
        vm.stopPrank();
    }
    
    function testEarlyVotingClosure() public {
        _registerJurors();
        uint256 disputeId = _createDispute();
        _assignJurors(disputeId);
        
        address[] memory assignedJurors = voteContract.getAssignedJurors(disputeId);
        
        // All jurors vote
        for (uint256 i = 0; i < assignedJurors.length; i++) {
            vm.startPrank(assignedJurors[i]);
            voteContract.castVote(disputeId, QJuryVote.VoteChoice.Support);
            vm.stopPrank();
        }
        
        // Should be able to close voting early when all votes are cast
        voteContract.closeVoting(disputeId);
        
        (,, bool isVotingClosed,,,,) = voteContract.getDisputeVoting(disputeId);
        assertTrue(isVotingClosed);
    }
}