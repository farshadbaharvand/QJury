// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title QJuryRegistry
 * @dev Manages juror registration, staking, and status tracking
 */
contract QJuryRegistry {
    struct Juror {
        bool isRegistered;
        uint256 stakedAmount;
        uint256 totalVotes;
        uint256 correctVotes;
        bool isSlashed;
    }
    
    mapping(address => Juror) public jurors;
    address[] public jurorList;
    
    uint256 public constant MINIMUM_STAKE = 0.1 ether;
    uint256 public totalRegisteredJurors;
    
    event JurorRegistered(address indexed juror, uint256 stakedAmount);
    event JurorSlashed(address indexed juror, uint256 slashedAmount);
    event StakeWithdrawn(address indexed juror, uint256 amount);
    
    modifier onlyRegisteredJuror() {
        require(jurors[msg.sender].isRegistered, "Not a registered juror");
        _;
    }
    
    modifier notSlashed() {
        require(!jurors[msg.sender].isSlashed, "Juror is slashed");
        _;
    }
    
    /**
     * @dev Register as a juror by staking ETH
     */
    function registerJuror() external payable {
        require(msg.value >= MINIMUM_STAKE, "Insufficient stake");
        require(!jurors[msg.sender].isRegistered, "Already registered");
        
        jurors[msg.sender] = Juror({
            isRegistered: true,
            stakedAmount: msg.value,
            totalVotes: 0,
            correctVotes: 0,
            isSlashed: false
        });
        
        jurorList.push(msg.sender);
        totalRegisteredJurors++;
        
        emit JurorRegistered(msg.sender, msg.value);
    }
    
    /**
     * @dev Slash a juror for voting against the majority
     * @param juror The address of the juror to slash
     * @param slashAmount The amount to slash
     */
    function slashJuror(address juror, uint256 slashAmount) external {
        // This should only be called by authorized contracts (QJuryReward)
        require(jurors[juror].isRegistered, "Juror not registered");
        require(jurors[juror].stakedAmount >= slashAmount, "Insufficient stake to slash");
        
        jurors[juror].stakedAmount -= slashAmount;
        
        // If stake falls below minimum, mark as slashed
        if (jurors[juror].stakedAmount < MINIMUM_STAKE) {
            jurors[juror].isSlashed = true;
        }
        
        emit JurorSlashed(juror, slashAmount);
    }
    
    /**
     * @dev Record a vote for statistical tracking
     * @param juror The address of the juror
     * @param wasCorrect Whether the vote was with the majority
     */
    function recordVote(address juror, bool wasCorrect) external {
        require(jurors[juror].isRegistered, "Juror not registered");
        
        jurors[juror].totalVotes++;
        if (wasCorrect) {
            jurors[juror].correctVotes++;
        }
    }
    
    /**
     * @dev Withdraw stake (only if not slashed and sufficient balance)
     * @param amount The amount to withdraw
     */
    function withdrawStake(uint256 amount) external onlyRegisteredJuror notSlashed {
        require(jurors[msg.sender].stakedAmount >= amount, "Insufficient stake");
        require(jurors[msg.sender].stakedAmount - amount >= MINIMUM_STAKE, "Would fall below minimum stake");
        
        jurors[msg.sender].stakedAmount -= amount;
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit StakeWithdrawn(msg.sender, amount);
    }
    
    /**
     * @dev Get juror information
     * @param juror The address of the juror
     * @return The juror struct
     */
    function getJuror(address juror) external view returns (Juror memory) {
        return jurors[juror];
    }
    
    /**
     * @dev Get all registered juror addresses
     * @return Array of juror addresses
     */
    function getAllJurors() external view returns (address[] memory) {
        return jurorList;
    }
    
    /**
     * @dev Get eligible jurors (registered and not slashed)
     * @return Array of eligible juror addresses
     */
    function getEligibleJurors() external view returns (address[] memory) {
        address[] memory eligibleJurors = new address[](totalRegisteredJurors);
        uint256 count = 0;
        
        for (uint256 i = 0; i < jurorList.length; i++) {
            if (jurors[jurorList[i]].isRegistered && !jurors[jurorList[i]].isSlashed) {
                eligibleJurors[count] = jurorList[i];
                count++;
            }
        }
        




        // Resize array to actual count
        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = eligibleJurors[i];
        }
        
        return result;
    }
    

    
    /**
     * @dev Check if an address is an eligible juror
     * @param juror The address to check
     * @return Whether the address is an eligible juror
     */
    function isEligibleJuror(address juror) external view returns (bool) {
        return jurors[juror].isRegistered && !jurors[juror].isSlashed;
    }
}