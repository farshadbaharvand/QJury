// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


/**
 * @title MockQRandomOracle
 * @dev Mock quantum random number oracle for testing QJury system
 */
contract MockQRandomOracle {
    mapping(uint256 => uint256) private randomValues;
    mapping(uint256 => bool) private requestFulfilled;
    uint256 private requestCounter;
    
    event RandomnessRequested(uint256 indexed requestId);
    event RandomnessFulfilled(uint256 indexed requestId, uint256 randomValue);
    
    /**
     * @dev Request a random number
     * @return requestId The ID of the randomness request
     */
    function requestRandomness() external returns (uint256 requestId) {
        requestId = ++requestCounter;
        emit RandomnessRequested(requestId);
        return requestId;
    }
    
    /**
     * @dev Manually set a random value for testing (only for mock)
     * @param requestId The request ID to fulfill
     * @param randomValue The random value to set
     */
    function setRandomValue(uint256 requestId, uint256 randomValue) external {
        require(!requestFulfilled[requestId], "Request already fulfilled");
        randomValues[requestId] = randomValue;
        requestFulfilled[requestId] = true;
        emit RandomnessFulfilled(requestId, randomValue);
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
}