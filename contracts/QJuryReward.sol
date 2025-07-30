// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./QJuryRegistry.sol";
import "./QJuryVote.sol";
import "./QJuryDispute.sol";

/**
 * @title QJuryReward
 * @dev Manages reward distribution and slashing based on voting outcomes
 */
contract QJuryReward {
    struct RewardDistribution {
        uint256 disputeId;
        uint256 totalRewardPool;
        uint256 rewardPerCorrectVote;
        uint256 slashAmount;
        bool isDistributed;
        address[] correctVoters;
        address[] incorrectVoters;
    }
    
    mapping(uint256 => RewardDistribution) public distributions;
    
    QJuryRegistry public immutable registry;
    QJuryVote public immutable voteContract;
    QJuryDispute public immutable disputeContract;
    
    uint256 public constant SLASH_PERCENTAGE = 10; // 10% of stake
    uint256 public constant BASE_REWARD = 0.001 ether; // Base reward per correct vote
    
    event RewardsDistributed(uint256 indexed disputeId, uint256 totalRewards, address[] correctVoters);
    event JurorSlashed(uint256 indexed disputeId, address indexed juror, uint256 slashAmount);
    event JurorRewarded(uint256 indexed disputeId, address indexed juror, uint256 rewardAmount);
    
    modifier onlyResolvedDispute(uint256 disputeId) {
        (, , bool isVotingClosed, , , , ) = voteContract.getDisputeVoting(disputeId);
        require(isVotingClosed, "Voting not closed");
        
        QJuryDispute.Dispute memory dispute = disputeContract.getDispute(disputeId);
        require(dispute.status == QJuryDispute.DisputeStatus.Resolved, "Dispute not resolved");
        _;
    }
    
    constructor(address _registry, address _voteContract, address _disputeContract) {
        registry = QJuryRegistry(_registry);
        voteContract = QJuryVote(_voteContract);
        disputeContract = QJuryDispute(_disputeContract);
    }
    
    /**
     * @dev Distribute rewards and apply slashing after dispute resolution
     * @param disputeId The ID of the resolved dispute
     */
    function distributeRewards(uint256 disputeId) external onlyResolvedDispute(disputeId) {
        require(!distributions[disputeId].isDistributed, "Rewards already distributed");
        
        // Get voting results
        (
            address[] memory assignedJurors,
            ,
            ,
            QJuryVote.VoteChoice majorityChoice,
            ,
            ,
        ) = voteContract.getDisputeVoting(disputeId);
        
        require(majorityChoice != QJuryVote.VoteChoice.Abstain, "No clear majority");
        
        // Calculate rewards and slashing
        (
            address[] memory correctVoters,
            address[] memory incorrectVoters
        ) = _categorizeVoters(disputeId, assignedJurors, majorityChoice);
        
        uint256 totalSlashAmount = 0;
        uint256 totalRewardPool = 0;
        
        // Calculate total slash amount and reward pool
        QJuryDispute.Dispute memory dispute = disputeContract.getDispute(disputeId);
        totalRewardPool = dispute.fee + (correctVoters.length * BASE_REWARD);
        
        // Apply slashing to incorrect voters
        for (uint256 i = 0; i < incorrectVoters.length; i++) {
            uint256 slashAmount = _calculateSlashAmount(incorrectVoters[i]);
            totalSlashAmount += slashAmount;
            
            if (slashAmount > 0) {
                registry.slashJuror(incorrectVoters[i], slashAmount);
                registry.recordVote(incorrectVoters[i], false);
                emit JurorSlashed(disputeId, incorrectVoters[i], slashAmount);
            }
        }
        
        // Add slashed amount to reward pool
        totalRewardPool += totalSlashAmount;
        
        // Distribute rewards to correct voters
        uint256 rewardPerCorrectVote = correctVoters.length > 0 ? totalRewardPool / correctVoters.length : 0;
        
        for (uint256 i = 0; i < correctVoters.length; i++) {
            if (rewardPerCorrectVote > 0) {
                _transferReward(correctVoters[i], rewardPerCorrectVote);
                registry.recordVote(correctVoters[i], true);
                emit JurorRewarded(disputeId, correctVoters[i], rewardPerCorrectVote);
            }
        }
        
        // Record distribution
        distributions[disputeId] = RewardDistribution({
            disputeId: disputeId,
            totalRewardPool: totalRewardPool,
            rewardPerCorrectVote: rewardPerCorrectVote,
            slashAmount: totalSlashAmount,
            isDistributed: true,
            correctVoters: correctVoters,
            incorrectVoters: incorrectVoters
        });
        
        emit RewardsDistributed(disputeId, totalRewardPool, correctVoters);
    }
    
    /**
     * @dev Categorize voters as correct or incorrect based on majority vote
     * @param disputeId The ID of the dispute
     * @param assignedJurors Array of assigned jurors
     * @param majorityChoice The majority vote choice
     * @return correctVoters Array of jurors who voted with majority
     * @return incorrectVoters Array of jurors who voted against majority
     */
    function _categorizeVoters(
        uint256 disputeId,
        address[] memory assignedJurors,
        QJuryVote.VoteChoice majorityChoice
    ) internal view returns (address[] memory correctVoters, address[] memory incorrectVoters) {
        uint256 correctCount = 0;
        uint256 incorrectCount = 0;
        
        // First pass: count voters
        for (uint256 i = 0; i < assignedJurors.length; i++) {
            address juror = assignedJurors[i];
            if (voteContract.hasJurorVoted(disputeId, juror)) {
                QJuryVote.VoteChoice jurorVote = voteContract.getJurorVote(disputeId, juror);
                if (jurorVote == majorityChoice) {
                    correctCount++;
                } else if (jurorVote != QJuryVote.VoteChoice.Abstain) {
                    incorrectCount++;
                }
            }
        }
        
        // Initialize arrays
        correctVoters = new address[](correctCount);
        incorrectVoters = new address[](incorrectCount);
        
        uint256 correctIndex = 0;
        uint256 incorrectIndex = 0;
        
        // Second pass: populate arrays
        for (uint256 i = 0; i < assignedJurors.length; i++) {
            address juror = assignedJurors[i];
            if (voteContract.hasJurorVoted(disputeId, juror)) {
                QJuryVote.VoteChoice jurorVote = voteContract.getJurorVote(disputeId, juror);
                if (jurorVote == majorityChoice) {
                    correctVoters[correctIndex] = juror;
                    correctIndex++;
                } else if (jurorVote != QJuryVote.VoteChoice.Abstain) {
                    incorrectVoters[incorrectIndex] = juror;
                    incorrectIndex++;
                }
            }
        }
        
        return (correctVoters, incorrectVoters);
    }
    
    /**
     * @dev Calculate slash amount for a juror
     * @param juror The address of the juror
     * @return The amount to slash
     */
    function _calculateSlashAmount(address juror) internal view returns (uint256) {
        QJuryRegistry.Juror memory jurorInfo = registry.getJuror(juror);
        
        if (!jurorInfo.isRegistered || jurorInfo.isSlashed) {
            return 0;
        }
        
        uint256 slashAmount = (jurorInfo.stakedAmount * SLASH_PERCENTAGE) / 100;
        
        // Ensure we don't slash more than available stake
        return slashAmount > jurorInfo.stakedAmount ? jurorInfo.stakedAmount : slashAmount;
    }
    
    /**
     * @dev Transfer reward to a juror
     * @param juror The address of the juror
     * @param amount The reward amount
     */
    function _transferReward(address juror, uint256 amount) internal {
        (bool success, ) = payable(juror).call{value: amount}("");
        require(success, "Reward transfer failed");
    }
    
    /**
     * @dev Get reward distribution information
     * @param disputeId The ID of the dispute
     * @return The reward distribution struct
     */
    function getRewardDistribution(uint256 disputeId) external view returns (RewardDistribution memory) {
        return distributions[disputeId];
    }
    
    /**
     * @dev Check if rewards have been distributed for a dispute
     * @param disputeId The ID of the dispute
     * @return Whether rewards have been distributed
     */
    function areRewardsDistributed(uint256 disputeId) external view returns (bool) {
        return distributions[disputeId].isDistributed;
    }
    
    /**
     * @dev Get correct voters for a dispute
     * @param disputeId The ID of the dispute
     * @return Array of correct voter addresses
     */
    function getCorrectVoters(uint256 disputeId) external view returns (address[] memory) {
        return distributions[disputeId].correctVoters;
    }
    
    /**
     * @dev Get incorrect voters for a dispute
     * @param disputeId The ID of the dispute
     * @return Array of incorrect voter addresses
     */
    function getIncorrectVoters(uint256 disputeId) external view returns (address[] memory) {
        return distributions[disputeId].incorrectVoters;
    }
    
    /**
     * @dev Emergency withdraw function (only for governance)
     * @param amount The amount to withdraw
     */
    function emergencyWithdraw(uint256 amount) external {
        // In a real implementation, this would have proper governance controls
        require(amount <= address(this).balance, "Insufficient balance");
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }
    
    /**
     * @dev Receive function to accept ETH
     */
    receive() external payable {}
}