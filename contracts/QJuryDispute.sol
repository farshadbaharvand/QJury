// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./QJuryRegistry.sol";
import "./QJuryVote.sol";
import "./QuantumRandomOracle.sol";

/**
 * @title QJuryDispute
 * @dev Manages dispute creation, quantum randomness, and juror assignment
 */
contract QJuryDispute {
    enum DisputeStatus { Created, JurorsAssigned, VotingStarted, Resolved }
    
    struct Dispute {
        uint256 id;
        address creator;
        string description;
        uint256 fee;
        uint256 createdAt;
        DisputeStatus status;
        address[] assignedJurors;
        uint256 randomnessRequestId;
        bool randomnessFulfilled;
        uint256 metadata; // Additional metadata for frontend
    }
    
    mapping(uint256 => Dispute) public disputes;
    uint256 public disputeCounter;
    
    QJuryRegistry public immutable registry;
    QJuryVote public immutable voteContract;
    QuantumRandomOracle public immutable randomOracle;
    
    uint256 public constant DISPUTE_FEE = 0.01 ether;
    uint256 public constant JURORS_PER_DISPUTE = 10;
    
    event DisputeCreated(uint256 indexed disputeId, address indexed creator, string description, uint256 fee, uint256 timestamp);
    event RandomnessRequested(uint256 indexed disputeId, uint256 randomnessRequestId, uint256 timestamp);
    event JurorsAssigned(uint256 indexed disputeId, address[] assignedJurors, uint256 timestamp);
    event DisputeResolved(uint256 indexed disputeId, uint256 timestamp);
    event DisputeMetadataUpdated(uint256 indexed disputeId, uint256 metadata);
    
    modifier onlyValidDispute(uint256 disputeId) {
        require(disputes[disputeId].id != 0, "Dispute does not exist");
        _;
    }
    

    constructor(address _registry, address _voteContract, address _randomOracle) {
        registry = QJuryRegistry(_registry);
        voteContract = QJuryVote(_voteContract);
        randomOracle = QuantumRandomOracle(_randomOracle);
    }
    


    
    /**
     * @dev Create a new dispute
     * @param description Description of the dispute
     */
    function createDispute(string calldata description) external payable returns (uint256 disputeId) {
        require(msg.value >= DISPUTE_FEE, "Insufficient dispute fee");
        require(bytes(description).length > 0, "Description cannot be empty");
        
        disputeId = ++disputeCounter;
        
        disputes[disputeId] = Dispute({
            id: disputeId,
            creator: msg.sender,
            description: description,
            fee: msg.value,
            createdAt: block.timestamp,
            status: DisputeStatus.Created,
            assignedJurors: new address[](0),
            randomnessRequestId: 0,
            randomnessFulfilled: false,
            metadata: 0
        });
        
        emit DisputeCreated(disputeId, msg.sender, description, msg.value, block.timestamp);
        
        // Immediately request randomness for juror selection
        _requestRandomnessForJurorSelection(disputeId);
        
        return disputeId;
    }
    
    /**
     * @dev Request quantum randomness for juror selection
     * @param disputeId The ID of the dispute
     */
    function _requestRandomnessForJurorSelection(uint256 disputeId) internal {
        uint256 requestId = randomOracle.requestRandomness();
        disputes[disputeId].randomnessRequestId = requestId;
        
        emit RandomnessRequested(disputeId, requestId, block.timestamp);
    }
    
    /**
     * @dev Assign jurors once randomness is fulfilled
     * @param disputeId The ID of the dispute
     */
    function assignJurors(uint256 disputeId) external onlyValidDispute(disputeId) {
        Dispute storage dispute = disputes[disputeId];
        require(dispute.status == DisputeStatus.Created, "Invalid dispute status");
        require(!dispute.randomnessFulfilled, "Jurors already assigned");
        require(randomOracle.isRequestFulfilled(dispute.randomnessRequestId), "Randomness not fulfilled");
        
        uint256 randomValue = randomOracle.getRandomValue(dispute.randomnessRequestId);
        address[] memory eligibleJurors = registry.getEligibleJurors();
        
        require(eligibleJurors.length >= JURORS_PER_DISPUTE, "Insufficient eligible jurors");
        
        // Select 10 random jurors using the quantum random number
        address[] memory selectedJurors = _selectRandomJurors(eligibleJurors, randomValue);
        
        dispute.assignedJurors = selectedJurors;
        dispute.status = DisputeStatus.JurorsAssigned;
        dispute.randomnessFulfilled = true;
        
        emit JurorsAssigned(disputeId, selectedJurors, block.timestamp);
        
        // Start voting immediately after juror assignment
        voteContract.startVoting(disputeId, selectedJurors);
        dispute.status = DisputeStatus.VotingStarted;
    }
    
    /**
     * @dev Select random jurors from eligible pool
     * @param eligibleJurors Array of eligible juror addresses
     * @param randomSeed The random seed from quantum oracle
     * @return selectedJurors Array of selected juror addresses
     */
    function _selectRandomJurors(address[] memory eligibleJurors, uint256 randomSeed) internal pure returns (address[] memory selectedJurors) {
        uint256 totalEligible = eligibleJurors.length;
        selectedJurors = new address[](JURORS_PER_DISPUTE);
        
        // Create a copy to avoid modifying the original array
        address[] memory availableJurors = new address[](totalEligible);
        for (uint256 i = 0; i < totalEligible; i++) {
            availableJurors[i] = eligibleJurors[i];
        }
        
        uint256 currentSeed = randomSeed;
        
        // Fisher-Yates shuffle algorithm to select random jurors
        for (uint256 i = 0; i < JURORS_PER_DISPUTE; i++) {
            uint256 remainingJurors = totalEligible - i;
            uint256 randomIndex = currentSeed % remainingJurors;
            
            selectedJurors[i] = availableJurors[randomIndex];
            
            // Swap selected juror with the last available juror
            availableJurors[randomIndex] = availableJurors[remainingJurors - 1];
            
            // Generate new seed for next iteration
            currentSeed = uint256(keccak256(abi.encodePacked(currentSeed, i)));
        }
        
        return selectedJurors;
    }
    
    /**
     * @dev Mark dispute as resolved
     * @param disputeId The ID of the dispute
     */
    function resolveDispute(uint256 disputeId) external onlyValidDispute(disputeId) {
        Dispute storage dispute = disputes[disputeId];
        require(dispute.status == DisputeStatus.VotingStarted, "Invalid dispute status");
        
        // Check if voting is closed
        (, , bool isVotingClosed, , , , ) = voteContract.getDisputeVoting(disputeId);
        require(isVotingClosed, "Voting not yet closed");
        
        dispute.status = DisputeStatus.Resolved;
        
        emit DisputeResolved(disputeId, block.timestamp);
    }
    
    /**
     * @dev Get dispute information
     * @param disputeId The ID of the dispute
     * @return The dispute struct
     */
    function getDispute(uint256 disputeId) external view returns (Dispute memory) {
        return disputes[disputeId];
    }
    
    /**
     * @dev Get assigned jurors for a dispute
     * @param disputeId The ID of the dispute
     * @return Array of assigned juror addresses
     */
    function getAssignedJurors(uint256 disputeId) external view returns (address[] memory) {
        return disputes[disputeId].assignedJurors;
    }
    
    /**
     * @dev Get total number of disputes
     * @return The total dispute count
     */
    function getTotalDisputes() external view returns (uint256) {
        return disputeCounter;
    }
    
    /**
     * @dev Check if jurors can be assigned (randomness fulfilled)
     * @param disputeId The ID of the dispute
     * @return Whether jurors can be assigned
     */
    function canAssignJurors(uint256 disputeId) external view returns (bool) {
        Dispute storage dispute = disputes[disputeId];
        return dispute.status == DisputeStatus.Created && 
               randomOracle.isRequestFulfilled(dispute.randomnessRequestId);
    }
    
    /**
     * @dev Update dispute metadata for frontend display
     * @param disputeId The ID of the dispute
     * @param metadata The metadata to set
     */
    function updateDisputeMetadata(uint256 disputeId, uint256 metadata) external onlyValidDispute(disputeId) {
        Dispute storage dispute = disputes[disputeId];
        require(dispute.creator == msg.sender, "Only dispute creator can update metadata");
        
        dispute.metadata = metadata;
        emit DisputeMetadataUpdated(disputeId, metadata);
    }
    
    /**
     * @dev Get dispute information with enhanced frontend data
     * @param disputeId The ID of the dispute
     * @return dispute The dispute struct with all details
     * @return canAssignJurorsbool Whether jurors can be assigned
     * @return eligibleJurorCount Number of eligible jurors
     */
    function getDisputeWithDetails(uint256 disputeId) external view returns (
        Dispute memory dispute,
        bool canAssignJurorsbool,
        uint256 eligibleJurorCount
    ) {
        dispute = disputes[disputeId];
        canAssignJurorsbool = this.canAssignJurors(disputeId);
        eligibleJurorCount = registry.getEligibleJurors().length;
    }
    
    /**
     * @dev Get time until randomness request expires
     * @param disputeId The ID of the dispute
     * @return timeUntilExpiry Time until randomness request expires
     */
    function getTimeUntilExpiry(uint256 disputeId) external view returns (uint256 timeUntilExpiry) {
        Dispute storage dispute = disputes[disputeId];
        
        if (dispute.randomnessRequestId > 0) {
            (bool fulfilled, , uint256 requestTime) = randomOracle.getRequestDetails(dispute.randomnessRequestId);
            if (!fulfilled && requestTime > 0) {
                uint256 expiryTime = requestTime + randomOracle.MAX_FULFILLMENT_DELAY();
                timeUntilExpiry = block.timestamp >= expiryTime ? 0 : expiryTime - block.timestamp;
            }
        }
    }
    
    /**
     * @dev Get all disputes for a creator
     * @param creator The address of the dispute creator
     * @return Array of dispute IDs created by the address
     */
    function getDisputesByCreator(address creator) external view returns (uint256[] memory) {
        uint256[] memory creatorDisputes = new uint256[](disputeCounter);
        uint256 count = 0;
        
        for (uint256 i = 1; i <= disputeCounter; i++) {
            if (disputes[i].creator == creator) {
                creatorDisputes[count] = i;
                count++;
            }
        }
        
        // Resize array to actual count
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = creatorDisputes[i];
        }
        
        return result;
    }
    
    /**
     * @dev Get disputes by status
     * @param status The dispute status to filter by
     * @return Array of dispute IDs with the specified status
     */
    function getDisputesByStatus(DisputeStatus status) external view returns (uint256[] memory) {
        uint256[] memory statusDisputes = new uint256[](disputeCounter);
        uint256 count = 0;
        
        for (uint256 i = 1; i <= disputeCounter; i++) {
            if (disputes[i].status == status) {
                statusDisputes[count] = i;
                count++;
            }
        }
        
        // Resize array to actual count
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = statusDisputes[i];
        }
        
        return result;
    }
    
    /**
     * @dev Withdraw accumulated fees (only contract owner or DAO)
     * @param amount The amount to withdraw
     */
    function withdrawFees(uint256 amount) external {
        // In a real implementation, this would have proper access control
        require(amount <= address(this).balance, "Insufficient balance");
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }
    
    /**
     * @dev Get contract balance
     * @return The contract's ETH balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}