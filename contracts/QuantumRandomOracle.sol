// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title QuantumRandomOracle
 * @dev Real quantum random number oracle for QJury system using ANU QRNG API
 */
contract QuantumRandomOracle {
    mapping(uint256 => uint256) private randomValues;
    mapping(uint256 => bool) private requestFulfilled;
    mapping(uint256 => uint256) private requestTimestamps;
    mapping(address => bool) private authorizedOracles;
    
    uint256 private requestCounter;
    uint256 public constant MAX_FULFILLMENT_DELAY = 1 hours; // Maximum time to fulfill request
    
    event RandomnessRequested(uint256 indexed requestId, uint256 timestamp);
    event RandomnessFulfilled(uint256 indexed requestId, uint256 randomValue, address indexed oracle);
    event OracleAuthorized(address indexed oracle, bool authorized);
    
    modifier onlyAuthorizedOracle() {
        require(authorizedOracles[msg.sender], "Not authorized oracle");
        _;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    address public immutable owner;
    
    constructor() {
        owner = msg.sender;
        authorizedOracles[msg.sender] = true; // Owner is initially authorized
    }
    
    /**
     * @dev Request a random number from quantum oracle
     * @return requestId The ID of the randomness request
     */
    function requestRandomness() external returns (uint256 requestId) {
        requestId = ++requestCounter;
        requestTimestamps[requestId] = block.timestamp;
        emit RandomnessRequested(requestId, block.timestamp);
        return requestId;
    }
    
    /**
     * @dev Fulfill randomness request with value from ANU QRNG API
     * @param requestId The request ID to fulfill
     * @param randomValue The random value from quantum source
     */
    function fulfillRandomness(uint256 requestId, uint256 randomValue) external onlyAuthorizedOracle {
        require(!requestFulfilled[requestId], "Request already fulfilled");
        require(requestTimestamps[requestId] > 0, "Request does not exist");
        require(
            block.timestamp <= requestTimestamps[requestId] + MAX_FULFILLMENT_DELAY,
            "Request expired"
        );
        
        randomValues[requestId] = randomValue;
        requestFulfilled[requestId] = true;
        
        emit RandomnessFulfilled(requestId, randomValue, msg.sender);
    }
    
    /**
     * @dev Get the random value for a request
     * @param requestId The request ID
     * @return randomValue The random value
     */
    function getRandomValue(uint256 requestId) external view returns (uint256 randomValue) {
        require(requestFulfilled[requestId], "Request not fulfilled");
        return randomValues[requestId];
    }
    
    /**
     * @dev Check if a request has been fulfilled
     * @param requestId The request ID
     * @return fulfilled Whether the request has been fulfilled
     */
    function isRequestFulfilled(uint256 requestId) external view returns (bool fulfilled) {
        return requestFulfilled[requestId];
    }
    
    /**
     * @dev Get request timestamp
     * @param requestId The request ID
     * @return timestamp When the request was made
     */
    function getRequestTimestamp(uint256 requestId) external view returns (uint256 timestamp) {
        return requestTimestamps[requestId];
    }
    
    /**
     * @dev Authorize or deauthorize an oracle address
     * @param oracle The oracle address
     * @param authorized Whether to authorize or deauthorize
     */
    function setOracleAuthorization(address oracle, bool authorized) external onlyOwner {
        authorizedOracles[oracle] = authorized;
        emit OracleAuthorized(oracle, authorized);
    }
    
    /**
     * @dev Check if an address is an authorized oracle
     * @param oracle The address to check
     * @return authorized Whether the address is authorized
     */
    function isAuthorizedOracle(address oracle) external view returns (bool authorized) {
        return authorizedOracles[oracle];
    }
    
    /**
     * @dev Get request details
     * @param requestId The request ID
     * @return fulfilled Whether fulfilled
     * @return randomValue The random value (if fulfilled)
     * @return timestamp When requested
     */
    function getRequestDetails(uint256 requestId) external view returns (
        bool fulfilled,
        uint256 randomValue,
        uint256 timestamp
    ) {
        return (
            requestFulfilled[requestId],
            randomValues[requestId],
            requestTimestamps[requestId]
        );
    }
} 