const express = require('express');
const path = require('path');
const { ethers } = require('ethers');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Import routes
const quantumRoutes = require('./routes/quantum');

// Contract ABI for the QuantumRandomOracle
const ORACLE_ABI = [
    "function fulfillRandomness(uint256 requestId, uint256 randomValue) external",
    "function isRequestFulfilled(uint256 requestId) external view returns (bool)",
    "function getRequestDetails(uint256 requestId) external view returns (bool fulfilled, uint256 randomValue, uint256 timestamp)",
    "event RandomnessRequested(uint256 indexed requestId, uint256 timestamp)",
    "event RandomnessFulfilled(uint256 indexed requestId, uint256 randomValue, address indexed oracle)"
];

// QJury Dispute ABI
const DISPUTE_ABI = [
    "function getDisputeWithDetails(uint256 disputeId) external view returns (tuple, bool, uint256, uint256)",
    "function getDispute(uint256 disputeId) external view returns (tuple)",
    "function getDisputeCount() external view returns (uint256)"
];

// Initialize provider and contracts
let provider, oracleContract, disputeContract;

try {
    provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
    oracleContract = new ethers.Contract(
        process.env.ORACLE_CONTRACT_ADDRESS,
        ORACLE_ABI,
        provider
    );
    disputeContract = new ethers.Contract(
        process.env.DISPUTE_CONTRACT_ADDRESS,
        DISPUTE_ABI,
        provider
    );
} catch (error) {
    console.error('Failed to initialize contracts:', error.message);
}

// Routes
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// API Routes
app.use('/api/quantum', quantumRoutes);

// API Routes
app.get('/api/status', async (req, res) => {
    try {
        const network = await provider.getNetwork();
        res.json({
            status: 'connected',
            network: network.name,
            oracleAddress: process.env.ORACLE_CONTRACT_ADDRESS,
            disputeAddress: process.env.DISPUTE_CONTRACT_ADDRESS
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/requests/:requestId', async (req, res) => {
    try {
        const requestId = req.params.requestId;
        const [fulfilled, randomValue, timestamp] = await oracleContract.getRequestDetails(requestId);
        
        res.json({
            requestId: parseInt(requestId),
            fulfilled: fulfilled,
            randomValue: randomValue.toString(),
            timestamp: timestamp.toString(),
            date: new Date(Number(timestamp) * 1000).toISOString()
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/disputes/:disputeId', async (req, res) => {
    try {
        const disputeId = req.params.disputeId;
        const [dispute, canAssignJurors, eligibleJurorCount, timeUntilExpiry] = 
            await disputeContract.getDisputeWithDetails(disputeId);
        
        res.json({
            disputeId: parseInt(disputeId),
            dispute: {
                creator: dispute.creator,
                fee: dispute.fee.toString(),
                randomnessRequestId: dispute.randomnessRequestId.toString(),
                assignedJurors: dispute.assignedJurors,
                votingStartTime: dispute.votingStartTime.toString(),
                votingEndTime: dispute.votingEndTime.toString(),
                resolved: dispute.resolved,
                majorityVote: dispute.majorityVote
            },
            canAssignJurors,
            eligibleJurorCount: eligibleJurorCount.toString(),
            timeUntilExpiry: timeUntilExpiry.toString()
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/disputes', async (req, res) => {
    try {
        const disputeCount = await disputeContract.getDisputeCount();
        const disputes = [];
        
        for (let i = 0; i < Math.min(disputeCount, 10); i++) {
            try {
                const dispute = await disputeContract.getDispute(i);
                disputes.push({
                    id: i,
                    creator: dispute.creator,
                    resolved: dispute.resolved,
                    votingEndTime: dispute.votingEndTime.toString()
                });
            } catch (error) {
                console.error(`Error fetching dispute ${i}:`, error.message);
            }
        }
        
        res.json({ disputes, total: disputeCount.toString() });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Error handling middleware
app.use((error, req, res, next) => {
    console.error('Error:', error);
    res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, () => {
    console.log(`🚀 QJury Oracle Web Interface running on http://localhost:${PORT}`);
    console.log(`📊 Monitor disputes and quantum randomness`);
});

module.exports = app;