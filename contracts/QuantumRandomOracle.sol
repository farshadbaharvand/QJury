// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title QuantumRandomOracle
 * @dev Oracle for receiving quantum randomness from external sources (ANU QRNG API)
 * Replaces the mock oracle with real quantum randomness integration
 */
contract QuantumRandomOracle {
    struct RandomnessRequest {
        uint256 requestId;
        address requester;
        uint256 timestamp;
        bool fulfilled;
        uint256 randomValue;
        uint256 blockNumber;
    }
    
    mapping(uint256 => RandomnessRequest) private requests;
    mapping(address => bool) public authorizedOracles;
    address public owner;
    uint256 private requestCounter;
    
    uint256 public constant REQUEST_TIMEOUT = 1 hours;
    uint256 public constant MIN_CONFIRMATIONS = 3;
    
    event RandomnessRequested(
        uint256 indexed requestId, 
        address indexed requester, 
        uint256 timestamp,
        uint256 blockNumber
    );
    
    event RandomnessFulfilled(
        uint256 indexed requestId, 
        uint256 randomValue, 
        address indexed oracle,
        uint256 timestamp
    );
    
    event OracleAuthorized(address indexed oracle, bool authorized);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }
    
    modifier onlyAuthorizedOracle() {
        require(authorizedOracles[msg.sender], "Not an authorized oracle");
        _;
    }
    
    modifier validRequest(uint256 requestId) {
        require(requests[requestId].requestId != 0, "Request does not exist");
        require(!requests[requestId].fulfilled, "Request already fulfilled");
        require(
            block.timestamp <= requests[requestId].timestamp + REQUEST_TIMEOUT,
            "Request has expired"
        );
        _;
    }
    
    constructor() {
        owner = msg.sender;
        authorizedOracles[msg.sender] = true; // Owner is initially authorized
        emit OwnershipTransferred(address(0), msg.sender);
        emit OracleAuthorized(msg.sender, true);
    }
    
    /**
     * @dev Transfer ownership of the contract
     * @param newOwner The address of the new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }
    
    /**
     * @dev Authorize or deauthorize an oracle address
     * @param oracle The oracle address to modify
     * @param authorized Whether the oracle should be authorized
     */
    function setOracleAuthorization(address oracle, bool authorized) external onlyOwner {
        require(oracle != address(0), "Oracle cannot be zero address");
        authorizedOracles[oracle] = authorized;
        emit OracleAuthorized(oracle, authorized);
    }
    
    /**
     * @dev Request quantum randomness
     * @return requestId The ID of the randomness request
     */
    function requestRandomness() external returns (uint256 requestId) {
        requestId = ++requestCounter;
        
        requests[requestId] = RandomnessRequest({
            requestId: requestId,
            requester: msg.sender,
            timestamp: block.timestamp,
            fulfilled: false,
            randomValue: 0,
            blockNumber: block.number
        });
        
        emit RandomnessRequested(requestId, msg.sender, block.timestamp, block.number);
        return requestId;
    }
    
    /**
     * @dev Fulfill a randomness request with quantum random value
     * @param requestId The request ID to fulfill
     * @param randomValue The quantum random value from external source
     */
    function fulfillRandomness(
        uint256 requestId, 
        uint256 randomValue
    ) external onlyAuthorizedOracle validRequest(requestId) {
        require(randomValue > 0, "Random value must be greater than 0");
        require(
            block.number >= requests[requestId].blockNumber + MIN_CONFIRMATIONS,
            "Not enough block confirmations"
        );
        
        requests[requestId].fulfilled = true;
        requests[requestId].randomValue = randomValue;
        
        emit RandomnessFulfilled(requestId, randomValue, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Get the random value for a fulfilled request
     * @param requestId The request ID
     * @return randomValue The random value
     */
    function getRandomValue(uint256 requestId) external view returns (uint256 randomValue) {
        require(requests[requestId].requestId != 0, "Request does not exist");
        require(requests[requestId].fulfilled, "Request not fulfilled");
        return requests[requestId].randomValue;
    }
    
    /**
     * @dev Check if a request has been fulfilled
     * @param requestId The request ID
     * @return fulfilled Whether the request has been fulfilled
     */
    function isRequestFulfilled(uint256 requestId) external view returns (bool fulfilled) {
        return requests[requestId].fulfilled;
    }
    
    /**
     * @dev Get complete request information
     * @param requestId The request ID
     * @return request The complete RandomnessRequest struct
     */
    function getRequest(uint256 requestId) external view returns (RandomnessRequest memory request) {
        require(requests[requestId].requestId != 0, "Request does not exist");
        return requests[requestId];
    }
    
    /**
     * @dev Check if request is expired
     * @param requestId The request ID
     * @return expired Whether the request has expired
     */
    function isRequestExpired(uint256 requestId) external view returns (bool expired) {
        if (requests[requestId].requestId == 0) return false;
        return block.timestamp > requests[requestId].timestamp + REQUEST_TIMEOUT;
    }
    
    /**
     * @dev Get total number of requests made
     * @return count The total request count
     */
    function getTotalRequests() external view returns (uint256 count) {
        return requestCounter;
    }
    
    /**
     * @dev Get pending requests (not fulfilled and not expired)
     * @return pendingRequests Array of pending request IDs
     */
    function getPendingRequests() external view returns (uint256[] memory pendingRequests) {
        uint256 pendingCount = 0;
        
        // First pass: count pending requests
        for (uint256 i = 1; i <= requestCounter; i++) {
            if (!requests[i].fulfilled && 
                block.timestamp <= requests[i].timestamp + REQUEST_TIMEOUT) {
                pendingCount++;
            }
        }
        
        // Second pass: populate array
        pendingRequests = new uint256[](pendingCount);
        uint256 index = 0;
        
        for (uint256 i = 1; i <= requestCounter; i++) {
            if (!requests[i].fulfilled && 
                block.timestamp <= requests[i].timestamp + REQUEST_TIMEOUT) {
                pendingRequests[index] = i;
                index++;
            }
        }
        
        return pendingRequests;
    }
    
    /**
     * @dev Emergency function to cancel expired unfulfilled requests
     * @param requestId The request ID to cancel
     */
    function cancelExpiredRequest(uint256 requestId) external {
        require(requests[requestId].requestId != 0, "Request does not exist");
        require(!requests[requestId].fulfilled, "Request already fulfilled");
        require(
            block.timestamp > requests[requestId].timestamp + REQUEST_TIMEOUT,
            "Request has not expired yet"
        );
        
        // Mark as fulfilled with a deterministic fallback value
        requests[requestId].fulfilled = true;
        requests[requestId].randomValue = uint256(
            keccak256(abi.encodePacked(
                block.timestamp,
                block.prevrandao,
                requestId,
                "EXPIRED_FALLBACK"
            ))
        );
        
        emit RandomnessFulfilled(
            requestId, 
            requests[requestId].randomValue, 
            address(this), 
            block.timestamp
        );
    }
}