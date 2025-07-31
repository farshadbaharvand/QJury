# QJury - Decentralized Dispute Resolution System

QJury is an on-chain decentralized dispute resolution system where randomly selected jurors vote on disputes. Jurors stake ETH to register, vote on disputes, and are rewarded or slashed depending on whether they vote with or against the majority. Random juror selection is done via a quantum random number oracle.

## System Overview

The QJury system consists of four main smart contracts that work together to provide a fair and decentralized dispute resolution mechanism:

1. **QJuryRegistry** - Manages juror registration and staking
2. **QJuryDispute** - Handles dispute creation and juror assignment
3. **QJuryVote** - Manages the voting process
4. **QJuryReward** - Distributes rewards and applies slashing
5. **MockQRandomOracle** - Quantum randomness simulation for testing

## Smart Contracts

### QJuryRegistry.sol
- **Purpose**: Juror registration with ETH stake, track juror status, allow slashing
- **Key Features**:
  - Minimum stake requirement: 0.1 ETH
  - Juror eligibility tracking
  - Stake withdrawal with minimum balance protection
  - Slashing mechanism for incorrect votes
  - Vote statistics tracking

### QJuryDispute.sol
- **Purpose**: Create disputes, request quantum randomness, assign jurors
- **Key Features**:
  - Dispute fee: 0.01 ETH
  - Automatic quantum randomness request
  - Random selection of 10 jurors per dispute
  - Fisher-Yates shuffle for fair selection
  - Dispute lifecycle management

### QJuryVote.sol
- **Purpose**: Jurors submit votes, enforce one vote per juror, track votes
- **Key Features**:
  - Three vote choices: Support, Against, Abstain
  - 3-day voting period
  - One vote per juror per dispute
  - Early voting closure when all votes cast
  - Majority determination

### QJuryReward.sol
- **Purpose**: Calculate majority vote, reward/slash jurors
- **Key Features**:
  - 10% slashing for incorrect votes
  - Reward distribution from dispute fees and slashed amounts
  - Base reward: 0.001 ETH per correct vote
  - Automatic reward calculation and distribution

### MockQRandomOracle.sol
- **Purpose**: Quantum random number oracle simulation for testing
- **Key Features**:
  - Manual randomness setting for tests
  - Request/fulfillment pattern
  - Randomness verification

## Getting Started

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js and npm (optional, for frontend development)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd qjury
```

2. Install dependencies:
```bash
forge install
```

3. Compile contracts:
```bash
forge build
```

4. Run tests:
```bash
forge test
```

## Testing

The project includes comprehensive tests covering:

### End-to-End Workflow Test
- Juror registration
- Dispute creation
- Random juror assignment
- Voting process
- Dispute resolution
- Reward distribution and slashing

### Unit Tests
- Juror registration validation
- Insufficient stake/fee handling
- Double voting prevention
- Non-assigned juror voting restriction
- Random juror selection verification
- Stake withdrawal mechanics
- Early voting closure

Run specific tests:
```bash
# Run all tests
forge test

# Run with verbose output
forge test -vvv

# Run specific test
forge test --match-test testFullQJuryWorkflow -vvv
```

## System Flow

1. **Juror Registration**
   - Jurors stake minimum 0.1 ETH
   - Registration tracked in QJuryRegistry

2. **Dispute Creation**
   - Anyone can create dispute with 0.01 ETH fee
   - System requests quantum randomness
   - Dispute recorded in QJuryDispute

3. **Juror Assignment**
   - 10 jurors randomly selected from eligible pool
   - Fisher-Yates shuffle ensures fairness
   - Voting period begins automatically

4. **Voting Process**
   - Assigned jurors vote: Support, Against, or Abstain
   - 3-day voting period
   - One vote per juror
   - Early closure if all votes cast

5. **Resolution & Rewards**
   - Majority vote determined
   - Correct voters receive rewards
   - Incorrect voters get 10% stake slashed
   - Rewards distributed from fees + slashed amounts

## Configuration

### Key Constants
- Minimum stake: `0.1 ETH`
- Dispute fee: `0.01 ETH`
- Jurors per dispute: `10`
- Voting period: `3 days`
- Slash percentage: `10%`
- Base reward: `0.001 ETH`

## Security Considerations

- **Access Control**: Registry functions should be restricted to authorized contracts
- **Reentrancy**: Safe ETH transfers implemented
- **Integer Overflow**: Using Solidity 0.8.19+ with built-in overflow protection
- **Randomness**: Production should use real quantum oracle, not mock
- **Governance**: Emergency functions need proper governance controls




## License

This project is licensed under the MIT License - see the LICENSE file for details.
