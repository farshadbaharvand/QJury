# QJury – Decentralized Jury System with Quantum Randomness

> A blockchain-based dispute resolution system powered by real quantum randomness from ANU's QRNG API

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)
[![Node.js](https://img.shields.io/badge/Node.js-18+-green.svg)](https://nodejs.org/)
[![Thirdweb Ready](https://img.shields.io/badge/Thirdweb-Ready-blue.svg)](https://thirdweb.com/)

## 🌟 Overview

QJury is a revolutionary decentralized jury system that brings fairness and transparency to blockchain dispute resolution through:

- **Quantum Randomness**: Real quantum random numbers from ANU's QRNG API for truly unbiased juror selection
- **Decentralized Governance**: Community-driven dispute resolution without central authorities
- **Economic Incentives**: Stake-based system with rewards for honest jurors and penalties for malicious actors
- **Thirdweb Integration**: Frontend-ready with comprehensive APIs and events for seamless UI development

## 🏗️ Architecture

```
┌─────────────────────┐    ┌──────────────────────┐    ┌─────────────────────┐
│   Frontend (React)  │    │  Quantum Oracle Bot  │    │   ANU QRNG API      │
│   + Thirdweb SDK    │    │   (Node.js Script)   │    │  (Quantum Source)   │
└──────────┬──────────┘    └─────────┬────────────┘    └─────────┬───────────┘
           │                         │                           │
           │ Smart Contract Calls    │ Fetches & Submits         │ Real Quantum
           │                         │ Randomness                │ Random Numbers
           ▼                         ▼                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Ethereum Blockchain                                │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐  │
│  │ QuantumRandom   │  │  QJuryRegistry  │  │       QJuryDispute          │  │
│  │     Oracle      │◄─┤   (Staking &    │◄─┤   (Dispute Creation &      │  │
│  │                 │  │  Juror Mgmt)    │  │   Quantum Juror Selection)  │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┬───────────────┘  │
│                                                          │                  │
│  ┌─────────────────┐  ┌─────────────────────────────────┐ │                  │
│  │   QJuryVote     │  │          QJuryReward            │ │                  │
│  │ (Voting Logic)  │◄─┤ (Rewards & Slashing Logic)     │◄┘                  │
│  └─────────────────┘  └─────────────────────────────────┘                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Node.js 16+ 
- Foundry toolkit
- Ethereum wallet with ETH for gas
- RPC endpoint (Infura, Alchemy, etc.)

### 1. Clone and Setup

```bash
git clone https://github.com/your-org/qjury-quantum.git
cd qjury-quantum

# Install dependencies
npm install
forge install

# Setup environment
cp .env.example .env
# Edit .env with your configuration
```

### 2. Compile and Test

```bash
# Compile contracts
npm run compile

# Run comprehensive test suite
npm run test

# Check test coverage
npm run coverage
```

### 3. Deploy Contracts

```bash
# Deploy to testnet
npm run deploy

# Or deploy with Foundry script
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast
```

### 4. Start Quantum Oracle

```bash
# Test quantum API connectivity
npm run test-api

# Start the quantum randomness fetcher
npm start
```

## 📋 Smart Contracts

### Core Contracts

| Contract | Purpose | Key Features |
|----------|---------|--------------|
| `QuantumRandomOracle` | Quantum randomness provider | ANU QRNG integration, authorization, expiry handling |
| `QJuryRegistry` | Juror management | Staking, eligibility, slashing protection |
| `QJuryDispute` | Dispute handling | Creation, quantum juror selection, status tracking |
| `QJuryVote` | Voting mechanism | Secure voting, deadline management, majority calculation |
| `QJuryReward` | Incentive system | Reward distribution, slashing logic, economic balancing |

### Quantum Randomness Flow

1. **Dispute Creation**: User creates dispute → System requests quantum randomness
2. **Quantum Fetch**: Oracle bot fetches real quantum random numbers from ANU API
3. **Randomness Submission**: Bot submits quantum randomness to oracle contract  
4. **Juror Selection**: System uses quantum randomness for Fisher-Yates shuffle selection
5. **Voting & Resolution**: Selected jurors vote → Majority decision → Rewards distributed

## 🔧 Configuration

### Environment Variables

```bash
# Blockchain
PRIVATE_KEY=your_private_key_here
RPC_URL=https://your-rpc-endpoint.com
ORACLE_CONTRACT_ADDRESS=0x...

# Contract Addresses (auto-filled after deployment)
QUANTUM_ORACLE_ADDRESS=0x...
DISPUTE_CONTRACT_ADDRESS=0x...
REGISTRY_CONTRACT_ADDRESS=0x...
VOTE_CONTRACT_ADDRESS=0x...
REWARD_CONTRACT_ADDRESS=0x...

# Quantum Configuration
ANU_QRNG_API_URL=https://qrng.anu.edu.au/API/jsonI.php?length=1&type=uint8
POLL_INTERVAL_MS=30000
MAX_RETRIES=3
```

### Contract Parameters

```solidity
// Key system constants
uint256 public constant MINIMUM_STAKE = 0.1 ether;
uint256 public constant DISPUTE_FEE = 0.01 ether;
uint256 public constant JURORS_PER_DISPUTE = 10;
uint256 public constant VOTING_PERIOD = 3 days;
uint256 public constant REQUEST_TIMEOUT = 1 hours;
uint256 public constant MIN_CONFIRMATIONS = 3;
uint256 public constant SLASH_PERCENTAGE = 10; // 10% of stake
```

## 🎮 Usage Examples

### Creating a Dispute

```javascript
// Using ethers.js
const dispute = await disputeContract.createDispute("Contract violation dispute", {
    value: ethers.parseEther("0.01")
});

// Using Thirdweb SDK
const dispute = await contract.call("createDispute", ["Contract violation dispute"], {
    value: "0.01"
});
```

### Registering as Juror

```javascript
// Stake ETH to become eligible juror
const registration = await registryContract.registerJuror({
    value: ethers.parseEther("0.1")
});
```

### Quantum Oracle Operations

```bash
# Check oracle authorization
npm run check-auth

# View pending randomness requests
npm run check-pending

# Test quantum API connectivity
npm run test-api
```

## 🧪 Testing

### Comprehensive Test Suite

```bash
# Run all tests with verbose output
forge test -vvv

# Run specific test contract
forge test --match-contract QJuryQuantumSystemTest

# Run with gas reporting
forge test --gas-report

# Fuzz testing with custom runs
forge test --fuzz-runs 10000
```

### Test Coverage

- ✅ Quantum oracle authorization and security
- ✅ Randomness request/fulfillment lifecycle
- ✅ Juror registration and eligibility
- ✅ Dispute creation and quantum juror selection
- ✅ Voting mechanisms and majority calculation
- ✅ Reward distribution and slashing logic
- ✅ Frontend integration views and events
- ✅ Edge cases and failure scenarios
- ✅ Fuzz testing for randomness values

## 🌐 Frontend Integration

### Thirdweb-Ready Features

```javascript
// Get dispute metadata for UI
const metadata = await contract.call("getDisputeMetadata", [disputeId]);

// Get user's disputes
const userDisputes = await contract.call("getDisputesByCreator", [userAddress]);

// Get recent disputes for dashboard
const recentDisputes = await contract.call("getRecentDisputes", [10]);

// Real-time event listening
contract.events.addEventListener("DisputeCreated", (event) => {
    console.log("New dispute:", event.data);
});

contract.events.addEventListener("QuantumRandomnessReceived", (event) => {
    console.log("Quantum randomness received:", event.data);
});
```

### Key Events for Frontend

- `DisputeCreated` - New dispute created
- `RandomnessRequested` - Quantum randomness requested  
- `QuantumRandomnessReceived` - Real quantum randomness received
- `JurorsAssigned` - Jurors selected and assigned
- `DisputeStatusChanged` - Status updates for UI
- `VoteCast` - Juror votes submitted
- `DisputeResolved` - Final resolution

## 🔒 Security Features

### Quantum Oracle Security
- **Authorization Control**: Only authorized oracles can submit randomness
- **Request Expiry**: Prevents stale randomness attacks
- **Block Confirmation**: Minimum confirmations before fulfillment
- **Fallback Mechanism**: Deterministic fallback for expired requests

### Economic Security  
- **Stake Requirements**: Minimum stake to participate as juror
- **Slashing Protection**: Economic penalties for malicious behavior
- **Reward Incentives**: Rewards for honest participation
- **Fee Structure**: Dispute fees fund the reward system

### Smart Contract Security
- **Access Controls**: Owner-only functions for critical operations
- **Input Validation**: Comprehensive parameter validation
- **State Consistency**: Proper state transitions and checks
- **Reentrancy Protection**: SafeMath and careful state management

## 🎯 Real Quantum Randomness

### Why Quantum Randomness?

Traditional blockchain systems rely on pseudo-random number generation, which can be predictable or manipulable. QJury uses **real quantum randomness** from the Australian National University's Quantum Random Number Generator:

- **True Randomness**: Based on quantum mechanical processes
- **Unpredictable**: Cannot be computed or predicted in advance
- **Unbiased**: No patterns or correlations
- **Verifiable**: Publicly accessible and auditable source

### ANU QRNG Integration

```javascript
// Fetch quantum randomness
const response = await fetch('https://qrng.anu.edu.au/API/jsonI.php?length=1&type=uint8');
const quantumData = await response.json();

// Expand to uint256 with additional entropy
const randomValue = ethers.solidityPackedKeccak256(
    ['uint8', 'uint256', 'string'],
    [quantumData.data[0], timestamp, 'ANU_QUANTUM']
);
```

## 📊 System Economics

### Fee Structure
- **Dispute Fee**: 0.01 ETH per dispute (funds reward pool)
- **Minimum Stake**: 0.1 ETH to become juror
- **Slashing Rate**: 10% of stake for incorrect votes
- **Base Reward**: 0.001 ETH per correct vote

### Reward Distribution
1. **Dispute Fee Pool**: Initial funding from dispute creator
2. **Slashing Pool**: Penalties from incorrect voters  
3. **Base Rewards**: Fixed rewards for participation
4. **Total Pool**: Combined and distributed to correct voters

## 🛣️ Roadmap

### Phase 1: Core System ✅
- [x] Quantum randomness oracle
- [x] Basic dispute resolution
- [x] Juror selection algorithm
- [x] Voting mechanism
- [x] Reward system

### Phase 2: Enhancement 🚧
- [ ] Multi-chain deployment
- [ ] Advanced voting strategies
- [ ] Reputation system
- [ ] Appeals mechanism
- [ ] DAO governance

### Phase 3: Ecosystem 📋
- [ ] Third-party integrations
- [ ] SDK development
- [ ] Mobile applications
- [ ] Cross-chain bridges
- [ ] Advanced analytics

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

```bash
# Fork the repository
git clone https://github.com/your-username/qjury-quantum.git
cd qjury-quantum

# Install dependencies
npm install
forge install

# Create feature branch
git checkout -b feature/your-feature-name

# Make changes and test
npm run test
npm run format
npm run lint

# Submit pull request
```

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Australian National University**: For providing public access to quantum random number generation
- **Foundry Team**: For the excellent development framework
- **Thirdweb**: For frontend integration capabilities
- **Ethereum Community**: For the decentralized infrastructure

## 📞 Support

- **Documentation**: [docs.qjury.com](https://docs.qjury.com)
- **Discord**: [discord.gg/qjury](https://discord.gg/qjury)
- **Twitter**: [@QJuryProtocol](https://twitter.com/QJuryProtocol)
- **Email**: support@qjury.com

---

**⚡ Powered by Real Quantum Randomness | Built for True Decentralization | Ready for Production**