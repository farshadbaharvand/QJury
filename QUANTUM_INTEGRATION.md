# QJury Quantum Randomness Integration

This document explains how to set up and use the quantum randomness integration for the QJury decentralized dispute resolution system.

## 🌌 Overview

The QJury system now integrates real quantum randomness from the Australian National University's (ANU) Quantum Random Number Generator (QRNG) API. This ensures truly random and unpredictable juror selection, making the system more secure and fair.

## 🏗️ Architecture

### Smart Contracts

1. **QuantumRandomOracle.sol** - Production quantum randomness oracle
2. **MockQRandomOracle.sol** - Testing oracle (for development)
3. **QJuryDispute.sol** - Updated to use quantum randomness
4. **QJuryRegistry.sol** - Juror management (unchanged)
5. **QJuryVote.sol** - Voting mechanism (unchanged)
6. **QJuryReward.sol** - Reward distribution (unchanged)

### Oracle Service

- **scripts/qrng-fetch.js** - Node.js service that fetches quantum randomness from ANU API

## 🚀 Quick Start

### 1. Install Dependencies

```bash
# Install Node.js dependencies
npm install

# Install Foundry (if not already installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. Environment Setup

```bash
# Copy environment template
cp env.example .env

# Edit .env with your configuration
nano .env
```

Required environment variables:
```env
RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
PRIVATE_KEY=0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
ORACLE_CONTRACT_ADDRESS=0x1234567890123456789012345678901234567890
```

### 3. Deploy Contracts

```bash
# Deploy to local network for testing
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Deploy to testnet
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
```

### 4. Configure Oracle Authorization

After deployment, authorize your oracle operator:

```bash
# Using cast (Foundry)
cast send $ORACLE_CONTRACT_ADDRESS "setOracleAuthorization(address,bool)" $ORACLE_OPERATOR_ADDRESS true --private-key $PRIVATE_KEY
```

### 5. Start Oracle Service

```bash
# Monitor for new requests (production)
npm run monitor

# Test quantum randomness fetch
npm run test

# Fulfill specific request
npm run fulfill 1
```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `RPC_URL` | Ethereum RPC endpoint | `https://eth-mainnet.g.alchemy.com/v2/...` |
| `PRIVATE_KEY` | Oracle operator private key | `0x1234...` |
| `ORACLE_CONTRACT_ADDRESS` | Deployed oracle contract | `0x1234...` |
| `ETHERSCAN_URL` | Etherscan URL for links | `https://etherscan.io` |
| `CHAIN_ID` | Network chain ID | `1` (mainnet) |

### Network Configuration

- **Mainnet**: `CHAIN_ID=1`, `ETHERSCAN_URL=https://etherscan.io`
- **Goerli**: `CHAIN_ID=5`, `ETHERSCAN_URL=https://goerli.etherscan.io`
- **Sepolia**: `CHAIN_ID=11155111`, `ETHERSCAN_URL=https://sepolia.etherscan.io`

## 🧪 Testing

### Run Foundry Tests

```bash
# Run all tests
forge test

# Run quantum integration tests only
forge test --match-contract QuantumIntegrationTest

# Run with verbose output
forge test -vvv

# Run specific test
forge test --match-test testQuantumOracleDeployment -vvv
```

### Test Oracle Service

```bash
# Test quantum randomness fetch
npm run test

# Expected output:
# 🌌 Fetching quantum randomness from ANU QRNG API...
# ✅ Quantum randomness fetched: 42
# ✅ Test successful! Random value: 42
```

## 🔄 Workflow

### 1. Dispute Creation
When a dispute is created, the system automatically requests quantum randomness:

```solidity
// QJuryDispute.sol
function createDispute(string calldata description) external payable {
    // ... dispute creation logic ...
    
    // Request quantum randomness
    _requestRandomnessForJurorSelection(disputeId);
}
```

### 2. Oracle Service Monitoring
The oracle service monitors for new randomness requests:

```javascript
// scripts/qrng-fetch.js
oracleContract.on('RandomnessRequested', async (requestId, timestamp, event) => {
    // Fetch quantum randomness from ANU API
    const randomValue = await oracle.fetchQuantumRandomness();
    
    // Fulfill the request
    await oracle.fulfillRandomnessRequest(requestId, randomValue);
});
```

### 3. Juror Assignment
Once randomness is fulfilled, jurors can be assigned:

```solidity
// QJuryDispute.sol
function assignJurors(uint256 disputeId) external {
    // Verify randomness is fulfilled
    require(randomOracle.isRequestFulfilled(dispute.randomnessRequestId));
    
    // Get quantum random value
    uint256 randomValue = randomOracle.getRandomValue(dispute.randomnessRequestId);
    
    // Select jurors using quantum randomness
    address[] memory selectedJurors = _selectRandomJurors(eligibleJurors, randomValue);
}
```

## 🔒 Security Features

### Access Control
- Only authorized oracle operators can fulfill randomness requests
- Oracle authorization is managed by the contract owner
- Requests have a maximum fulfillment delay (1 hour)

### Request Validation
- Prevents double fulfillment
- Validates request existence
- Enforces time limits

### Quantum Security
- Uses ANU's quantum random number generator
- True randomness from quantum phenomena
- No deterministic patterns

## 📊 Monitoring

### Events
The system emits detailed events for monitoring:

```solidity
event RandomnessRequested(uint256 indexed requestId, uint256 timestamp);
event RandomnessFulfilled(uint256 indexed requestId, uint256 randomValue, address indexed oracle);
event OracleAuthorized(address indexed oracle, bool authorized);
```

### Frontend Integration
Enhanced functions for frontend monitoring:

```solidity
function getDisputeWithDetails(uint256 disputeId) external view returns (
    Dispute memory dispute,
    bool canAssignJurors,
    uint256 eligibleJurorCount,
    uint256 timeUntilExpiry
);
```

## 🚨 Troubleshooting

### Common Issues

1. **Oracle not authorized**
   ```
   Error: Not authorized oracle
   Solution: Authorize the oracle address using setOracleAuthorization()
   ```

2. **Request expired**
   ```
   Error: Request expired
   Solution: Check oracle service is running and fulfilling requests promptly
   ```

3. **API timeout**
   ```
   Error: API request failed
   Solution: Check network connectivity and ANU API status
   ```

### Debug Commands

```bash
# Check oracle authorization
cast call $ORACLE_CONTRACT_ADDRESS "isAuthorizedOracle(address)" $ORACLE_OPERATOR_ADDRESS

# Check request status
cast call $ORACLE_CONTRACT_ADDRESS "getRequestDetails(uint256)" 1

# Check dispute randomness status
cast call $DISPUTE_CONTRACT_ADDRESS "canAssignJurors(uint256)" 1
```

## 🔄 Migration from Mock Oracle

To migrate from the mock oracle to the quantum oracle:

1. Deploy the new `QuantumRandomOracle` contract
2. Update the `QJuryDispute` contract to use the new oracle
3. Authorize oracle operators
4. Start the quantum oracle service
5. Test thoroughly before going live

## 📈 Performance

### Gas Costs
- Randomness request: ~50,000 gas
- Randomness fulfillment: ~30,000 gas
- Juror assignment: ~200,000 gas

### API Response Time
- ANU QRNG API: ~100-500ms
- Total fulfillment time: ~1-2 seconds

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔗 Links

- [ANU QRNG API Documentation](https://qrng.anu.edu.au/contact/api-documentation/)
- [Foundry Documentation](https://book.getfoundry.sh/)
- [Ethers.js Documentation](https://docs.ethers.org/)
- [QJury Main Documentation](./README.md) 