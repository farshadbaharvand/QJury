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
    }
    
    mapping(uint256 => Dispute) public disputes;
    uint256 public disputeCounter;
    
    QJuryRegistry public immutable registry;
    QJuryVote public immutable voteContract;
    QuantumRandomOracle public immutable quantumOracle;
    
    uint256 public constant DISPUTE_FEE = 0.01 ether;
    uint256 public constant JURORS_PER_DISPUTE = 10;
    
    event DisputeCreated(uint256 indexed disputeId, address indexed creator, string description, uint256 fee);
    event RandomnessRequested(uint256 indexed disputeId, uint256 randomnessRequestId);
    event JurorsAssigned(uint256 indexed disputeId, address[] assignedJurors);
    event DisputeResolved(uint256 indexed disputeId);
    event DisputeStatusChanged(uint256 indexed disputeId, DisputeStatus indexed oldStatus, DisputeStatus indexed newStatus);
    event QuantumRandomnessReceived(uint256 indexed disputeId, uint256 randomValue, uint256 timestamp);
    
    modifier onlyValidDispute(uint256 disputeId) {
        require(disputes[disputeId].id != 0, "Dispute does not exist");
        _;
    }
    

    constructor(address _registry, address _voteContract, address _quantumOracle) {
        registry = QJuryRegistry(_registry);
        voteContract = QJuryVote(_voteContract);
        quantumOracle = QuantumRandomOracle(_quantumOracle);
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
            randomnessFulfilled: false
        });
        
        emit DisputeCreated(disputeId, msg.sender, description, msg.value);
        
        // Immediately request randomness for juror selection
        _requestRandomnessForJurorSelection(disputeId);
        
        return disputeId;
    }
    
    /**
     * @dev Request quantum randomness for juror selection
     * @param disputeId The ID of the dispute
     */
    function _requestRandomnessForJurorSelection(uint256 disputeId) internal {
        uint256 requestId = quantumOracle.requestRandomness();
        disputes[disputeId].randomnessRequestId = requestId;
        
        emit RandomnessRequested(disputeId, requestId);
    }
    
    /**
     * @dev Assign jurors once randomness is fulfilled
     * @param disputeId The ID of the dispute
     */
    function assignJurors(uint256 disputeId) external onlyValidDispute(disputeId) {
        Dispute storage dispute = disputes[disputeId];
        require(dispute.status == DisputeStatus.Created, "Invalid dispute status");
        require(!dispute.randomnessFulfilled, "Jurors already assigned");
        require(quantumOracle.isRequestFulfilled(dispute.randomnessRequestId), "Randomness not fulfilled");
        
        uint256 randomValue = quantumOracle.getRandomValue(dispute.randomnessRequestId);
        address[] memory eligibleJurors = registry.getEligibleJurors();
        
        require(eligibleJurors.length >= JURORS_PER_DISPUTE, "Insufficient eligible jurors");
        
        // Emit quantum randomness received event for frontend tracking
        emit QuantumRandomnessReceived(disputeId, randomValue, block.timestamp);
        
        // Select 10 random jurors using the quantum random number
        address[] memory selectedJurors = _selectRandomJurors(eligibleJurors, randomValue);
        
        DisputeStatus oldStatus = dispute.status;
        dispute.assignedJurors = selectedJurors;
        dispute.status = DisputeStatus.JurorsAssigned;
        dispute.randomnessFulfilled = true;
        
        emit DisputeStatusChanged(disputeId, oldStatus, DisputeStatus.JurorsAssigned);
        emit JurorsAssigned(disputeId, selectedJurors);
        
        // Start voting immediately after juror assignment
        voteContract.startVoting(disputeId, selectedJurors);
        DisputeStatus prevStatus = dispute.status;
        dispute.status = DisputeStatus.VotingStarted;
        emit DisputeStatusChanged(disputeId, prevStatus, DisputeStatus.VotingStarted);
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
        
        DisputeStatus oldStatus = dispute.status;
        dispute.status = DisputeStatus.Resolved;
        
        emit DisputeStatusChanged(disputeId, oldStatus, DisputeStatus.Resolved);
        emit DisputeResolved(disputeId);
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
               quantumOracle.isRequestFulfilled(dispute.randomnessRequestId);
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
    
    /**
     * @dev Get quantum oracle address for frontend integration
     * @return The quantum oracle contract address
     */
    function getQuantumOracleAddress() external view returns (address) {
        return address(quantumOracle);
    }
    
    /**
     * @dev Get registry address for frontend integration
     * @return The registry contract address
     */
    function getRegistryAddress() external view returns (address) {
        return address(registry);
    }
    
    /**
     * @dev Get vote contract address for frontend integration
     * @return The vote contract address
     */
    function getVoteContractAddress() external view returns (address) {
        return address(voteContract);
    }
    
    /**
     * @dev Get dispute metadata for Thirdweb dashboard
     * @param disputeId The dispute ID
     * @return metadata JSON-like string with dispute information
     */
    function getDisputeMetadata(uint256 disputeId) external view returns (string memory metadata) {
        Dispute storage dispute = disputes[disputeId];
        require(dispute.id != 0, "Dispute does not exist");
        
        // Simplified metadata to avoid stack too deep
        return string(abi.encodePacked(
            '{"disputeId":"', _uint256ToString(disputeId), '",',
            '"status":"', _statusToString(dispute.status), '",',
            '"jurorsCount":"', _uint256ToString(dispute.assignedJurors.length), '"}'
        ));
    }
    
    /**
     * @dev Get dispute summary for dashboard display
     * @param disputeId The dispute ID
     * @return id The dispute ID
     * @return creator The creator address
     * @return status The current status
     * @return jurorsAssigned Number of jurors assigned
     * @return randomnessFulfilled Whether randomness has been fulfilled
     * @return createdAt Creation timestamp
     */
    function getDisputeSummary(uint256 disputeId) external view returns (
        uint256 id,
        address creator,
        DisputeStatus status,
        uint256 jurorsAssigned,
        bool randomnessFulfilled,
        uint256 createdAt
    ) {
        Dispute storage dispute = disputes[disputeId];
        require(dispute.id != 0, "Dispute does not exist");
        
        return (
            dispute.id,
            dispute.creator,
            dispute.status,
            dispute.assignedJurors.length,
            dispute.randomnessFulfilled,
            dispute.createdAt
        );
    }
    
    /**
     * @dev Get all disputes created by a specific address
     * @param creator The creator address
     * @return disputeIds Array of dispute IDs created by the address
     */
    function getDisputesByCreator(address creator) external view returns (uint256[] memory disputeIds) {
        uint256 count = 0;
        
        // Count disputes by creator
        for (uint256 i = 1; i <= disputeCounter; i++) {
            if (disputes[i].creator == creator) {
                count++;
            }
        }
        
        // Populate array
        disputeIds = new uint256[](count);
        uint256 index = 0;
        
        for (uint256 i = 1; i <= disputeCounter; i++) {
            if (disputes[i].creator == creator) {
                disputeIds[index] = i;
                index++;
            }
        }
        
        return disputeIds;
    }
    
    /**
     * @dev Get recent disputes (last N disputes)
     * @param limit Maximum number of disputes to return
     * @return disputeIds Array of recent dispute IDs
     */
    function getRecentDisputes(uint256 limit) external view returns (uint256[] memory disputeIds) {
        uint256 total = disputeCounter;
        uint256 count = limit > total ? total : limit;
        
        disputeIds = new uint256[](count);
        
        for (uint256 i = 0; i < count; i++) {
            disputeIds[i] = total - i;
        }
        
        return disputeIds;
    }
    
    // Helper functions for string conversion
    function _uint256ToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
    
    function _addressToString(address addr) internal pure returns (string memory) {
        bytes memory data = abi.encodePacked(addr);
        bytes memory alphabet = "0123456789abcdef";
        
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            str[2+i*2] = alphabet[uint256(uint8(data[i] >> 4))];
            str[3+i*2] = alphabet[uint256(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }
    
    function _statusToString(DisputeStatus status) internal pure returns (string memory) {
        if (status == DisputeStatus.Created) return "Created";
        if (status == DisputeStatus.JurorsAssigned) return "JurorsAssigned";
        if (status == DisputeStatus.VotingStarted) return "VotingStarted";
        if (status == DisputeStatus.Resolved) return "Resolved";
        return "Unknown";
    }
}