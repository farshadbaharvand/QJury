// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./QJuryRegistry.sol";

/**
 * @title QJuryVote
 * @dev Manages voting mechanism for disputes with one vote per juror
 */
contract QJuryVote {
    enum VoteChoice { Abstain, Support, Against }
    
    struct Vote {
        address juror;
        VoteChoice choice;
        uint256 timestamp;
    }
    
    struct DisputeVoting {
        uint256 disputeId;
        address[] assignedJurors;
        mapping(address => bool) hasVoted;
        mapping(address => VoteChoice) votes;
        Vote[] voteList;
        uint256 votingDeadline;
        bool isVotingClosed;
        VoteChoice majorityChoice;
        uint256 supportVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
    }
    
    mapping(uint256 => DisputeVoting) public disputeVotings;
    QJuryRegistry public immutable registry;
    
    uint256 public constant VOTING_PERIOD = 3 days;
    
    event VoteCast(uint256 indexed disputeId, address indexed juror, VoteChoice choice);
    event VotingClosed(uint256 indexed disputeId, VoteChoice majorityChoice);
    event VotingStarted(uint256 indexed disputeId, address[] assignedJurors, uint256 deadline);
    
    modifier onlyEligibleJuror(uint256 disputeId) {
        require(registry.isEligibleJuror(msg.sender), "Not an eligible juror");
        require(isJurorAssigned(disputeId, msg.sender), "Juror not assigned to this dispute");
        _;
    }
    
    modifier votingOpen(uint256 disputeId) {
        require(!disputeVotings[disputeId].isVotingClosed, "Voting is closed");
        require(block.timestamp <= disputeVotings[disputeId].votingDeadline, "Voting period expired");
        _;
    }
    

    constructor(address _registry) {
        registry = QJuryRegistry(_registry);
    }
    


    
    /**
     * @dev Start voting for a dispute with assigned jurors
     * @param disputeId The ID of the dispute
     * @param assignedJurors Array of juror addresses assigned to this dispute
     */
    function startVoting(uint256 disputeId, address[] calldata assignedJurors) external {
        require(disputeVotings[disputeId].disputeId == 0, "Voting already started for this dispute");
        require(assignedJurors.length > 0, "No jurors assigned");
        
        DisputeVoting storage voting = disputeVotings[disputeId];
        voting.disputeId = disputeId;
        voting.assignedJurors = assignedJurors;
        voting.votingDeadline = block.timestamp + VOTING_PERIOD;
        voting.isVotingClosed = false;
        
        emit VotingStarted(disputeId, assignedJurors, voting.votingDeadline);
    }
    
    /**
     * @dev Cast a vote for a dispute
     * @param disputeId The ID of the dispute
     * @param choice The vote choice (Support, Against, or Abstain)
     */
    function castVote(uint256 disputeId, VoteChoice choice) external onlyEligibleJuror(disputeId) votingOpen(disputeId) {
        require(!disputeVotings[disputeId].hasVoted[msg.sender], "Already voted");
        require(choice != VoteChoice.Abstain || choice == VoteChoice.Abstain, "Invalid vote choice");
        
        DisputeVoting storage voting = disputeVotings[disputeId];
        
        voting.hasVoted[msg.sender] = true;
        voting.votes[msg.sender] = choice;
        
        Vote memory newVote = Vote({
            juror: msg.sender,
            choice: choice,
            timestamp: block.timestamp
        });
        voting.voteList.push(newVote);
        
        // Update vote counts
        if (choice == VoteChoice.Support) {
            voting.supportVotes++;
        } else if (choice == VoteChoice.Against) {
            voting.againstVotes++;
        } else {
            voting.abstainVotes++;
        }
        
        emit VoteCast(disputeId, msg.sender, choice);
    }
    
    /**
     * @dev Close voting and determine majority choice
     * @param disputeId The ID of the dispute
     */
    function closeVoting(uint256 disputeId) external {
        DisputeVoting storage voting = disputeVotings[disputeId];
        require(voting.disputeId != 0, "Voting not started");
        require(!voting.isVotingClosed, "Voting already closed");
        require(
            block.timestamp > voting.votingDeadline || 
            voting.voteList.length == voting.assignedJurors.length,
            "Voting period not ended and not all votes cast"
        );
        
        voting.isVotingClosed = true;
        
        // Determine majority choice
        if (voting.supportVotes > voting.againstVotes && voting.supportVotes > voting.abstainVotes) {
            voting.majorityChoice = VoteChoice.Support;
        } else if (voting.againstVotes > voting.supportVotes && voting.againstVotes > voting.abstainVotes) {
            voting.majorityChoice = VoteChoice.Against;
        } else {
            voting.majorityChoice = VoteChoice.Abstain; // Tie or majority abstain
        }
        
        emit VotingClosed(disputeId, voting.majorityChoice);
    }
    
    /**
     * @dev Get vote information for a dispute
     * @param disputeId The ID of the dispute
     * @return assignedJurors Array of assigned juror addresses
     * @return votingDeadline Timestamp when voting ends
     * @return isVotingClosed Whether voting has been closed
     * @return majorityChoice The majority vote choice
     * @return supportVotes Number of support votes
     * @return againstVotes Number of against votes
     * @return abstainVotes Number of abstain votes
     */
    function getDisputeVoting(uint256 disputeId) external view returns (
        address[] memory assignedJurors,
        uint256 votingDeadline,
        bool isVotingClosed,
        VoteChoice majorityChoice,
        uint256 supportVotes,
        uint256 againstVotes,
        uint256 abstainVotes
    ) {
        DisputeVoting storage voting = disputeVotings[disputeId];
        return (
            voting.assignedJurors,
            voting.votingDeadline,
            voting.isVotingClosed,
            voting.majorityChoice,
            voting.supportVotes,
            voting.againstVotes,
            voting.abstainVotes
        );
    }
    
    /**
     * @dev Get all votes for a dispute
     * @param disputeId The ID of the dispute
     * @return Array of votes
     */
    function getDisputeVotes(uint256 disputeId) external view returns (Vote[] memory) {
        return disputeVotings[disputeId].voteList;
    }
    
    /**
     * @dev Get a juror's vote for a specific dispute
     * @param disputeId The ID of the dispute
     * @param juror The address of the juror
     * @return The vote choice
     */
    function getJurorVote(uint256 disputeId, address juror) external view returns (VoteChoice) {
        return disputeVotings[disputeId].votes[juror];
    }
    
    /**
     * @dev Check if a juror has voted for a dispute
     * @param disputeId The ID of the dispute
     * @param juror The address of the juror
     * @return Whether the juror has voted
     */
    function hasJurorVoted(uint256 disputeId, address juror) external view returns (bool) {
        return disputeVotings[disputeId].hasVoted[juror];
    }
    
    /**
     * @dev Check if a juror is assigned to a dispute
     * @param disputeId The ID of the dispute
     * @param juror The address of the juror
     * @return Whether the juror is assigned
     */
    function isJurorAssigned(uint256 disputeId, address juror) public view returns (bool) {
        address[] memory assignedJurors = disputeVotings[disputeId].assignedJurors;
        for (uint256 i = 0; i < assignedJurors.length; i++) {
            if (assignedJurors[i] == juror) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * @dev Get assigned jurors for a dispute
     * @param disputeId The ID of the dispute
     * @return Array of assigned juror addresses
     */
    function getAssignedJurors(uint256 disputeId) external view returns (address[] memory) {
        return disputeVotings[disputeId].assignedJurors;
    }
}