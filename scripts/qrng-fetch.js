const axios = require('axios');
const { ethers } = require('ethers');
require('dotenv').config();

// ANU QRNG API endpoint
const QRNG_API_URL = 'https://qrng.anu.edu.au/API/jsonI.php?length=1&type=uint8';

// Contract ABI for the QuantumRandomOracle
const ORACLE_ABI = [
    "function fulfillRandomness(uint256 requestId, uint256 randomValue) external",
    "function isRequestFulfilled(uint256 requestId) external view returns (bool)",
    "function getRequestDetails(uint256 requestId) external view returns (bool fulfilled, uint256 randomValue, uint256 timestamp)",
    "event RandomnessRequested(uint256 indexed requestId, uint256 timestamp)",
    "event RandomnessFulfilled(uint256 indexed requestId, uint256 randomValue, address indexed oracle)"
];

class QRNGOracle {
    constructor() {
        this.provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
        this.wallet = new ethers.Wallet(process.env.PRIVATE_KEY, this.provider);
        this.oracleContract = new ethers.Contract(
            process.env.ORACLE_CONTRACT_ADDRESS,
            ORACLE_ABI,
            this.wallet
        );
    }

    /**
     * Initialize the oracle and log connection details
     */
    async initialize() {
        console.log('🔗 Connected to network:', await this.provider.getNetwork());
        console.log('👤 Oracle address:', this.wallet.address);
        console.log('📋 Oracle contract:', process.env.ORACLE_CONTRACT_ADDRESS);
    }

    /**
     * Fetch quantum random number from ANU QRNG API
     * @returns {Promise<number>} Random number between 0-255
     */
    async fetchQuantumRandomness() {
        try {
            console.log('🌌 Fetching quantum randomness from ANU QRNG API...');
            
            const response = await axios.get(QRNG_API_URL, {
                timeout: 10000, // 10 second timeout
                headers: {
                    'User-Agent': 'QJury-Oracle/1.0'
                }
            });

            if (response.status !== 200) {
                throw new Error(`API request failed with status ${response.status}`);
            }

            const data = response.data;
            
            if (!data.success || !data.data || !Array.isArray(data.data) || data.data.length === 0) {
                throw new Error('Invalid response format from QRNG API');
            }

            const randomValue = data.data[0];
            console.log('✅ Quantum randomness fetched:', randomValue);
            
            return randomValue;
        } catch (error) {
            console.error('❌ Error fetching quantum randomness:', error.message);
            if (error.response) {
                console.error('Response status:', error.response.status);
                console.error('Response data:', error.response.data);
            }
            throw error;
        }
    }

    /**
     * Fulfill a randomness request in the smart contract
     * @param {number} requestId - The request ID to fulfill
     * @param {number} randomValue - The quantum random value
     */
    async fulfillRandomnessRequest(requestId, randomValue) {
        try {
            console.log(`🔐 Fulfilling randomness request ${requestId} with value ${randomValue}...`);
            
            // Check if request is already fulfilled
            const isFulfilled = await this.oracleContract.isRequestFulfilled(requestId);
            if (isFulfilled) {
                console.log('⚠️  Request already fulfilled, skipping...');
                return;
            }

            // Get request details for verification
            const [fulfilled, , timestamp] = await this.oracleContract.getRequestDetails(requestId);
            if (fulfilled) {
                console.log('⚠️  Request already fulfilled, skipping...');
                return;
            }

            console.log(`📅 Request timestamp: ${new Date(Number(timestamp) * 1000).toISOString()}`);

            // Estimate gas for the transaction
            const gasEstimate = await this.oracleContract.fulfillRandomness.estimateGas(requestId, randomValue);
            console.log(`⛽ Estimated gas: ${gasEstimate.toString()}`);

            // Send transaction
            const tx = await this.oracleContract.fulfillRandomness(requestId, randomValue, {
                gasLimit: gasEstimate * 120n / 100n // Add 20% buffer
            });

            console.log(`📤 Transaction sent: ${tx.hash}`);
            console.log('⏳ Waiting for confirmation...');

            // Wait for confirmation
            const receipt = await tx.wait();
            
            if (receipt.status === 1) {
                console.log('✅ Randomness request fulfilled successfully!');
                console.log(`🔗 Transaction: ${process.env.ETHERSCAN_URL || 'https://etherscan.io'}/tx/${tx.hash}`);
            } else {
                throw new Error('Transaction failed');
            }

        } catch (error) {
            console.error('❌ Error fulfilling randomness request:', error.message);
            throw error;
        }
    }

    /**
     * Monitor for new randomness requests and fulfill them
     */
    async monitorAndFulfillRequests() {
        console.log('👀 Starting to monitor for randomness requests...');
        
        // Listen for RandomnessRequested events
        this.oracleContract.on('RandomnessRequested', async (requestId, timestamp, event) => {
            console.log(`\n🎯 New randomness request detected!`);
            console.log(`📋 Request ID: ${requestId.toString()}`);
            console.log(`⏰ Timestamp: ${new Date(Number(timestamp) * 1000).toISOString()}`);
            console.log(`🔗 Transaction: ${event.log.transactionHash}`);
            
            try {
                // Fetch quantum randomness
                const randomValue = await this.fetchQuantumRandomness();
                
                // Fulfill the request
                await this.fulfillRandomnessRequest(requestId, randomValue);
                
            } catch (error) {
                console.error(`❌ Failed to process request ${requestId}:`, error.message);
            }
        });

        console.log('✅ Event listener active. Waiting for requests...');
        
        // Keep the process alive
        process.stdin.resume();
    }

    /**
     * Process a specific request ID
     * @param {number} requestId - The request ID to process
     */
    async processSpecificRequest(requestId) {
        console.log(`🎯 Processing specific request: ${requestId}`);
        
        try {
            // Check if request exists and is not fulfilled
            const [fulfilled, , timestamp] = await this.oracleContract.getRequestDetails(requestId);
            
            if (timestamp === 0n || timestamp === 0) {
                console.log('❌ Request does not exist');
                return;
            }
            
            if (fulfilled) {
                console.log('⚠️  Request already fulfilled');
                return;
            }

            // Fetch and fulfill
            const randomValue = await this.fetchQuantumRandomness();
            await this.fulfillRandomnessRequest(requestId, randomValue);
            
        } catch (error) {
            console.error('❌ Error processing request:', error.message);
        }
    }
}

// CLI interface
async function main() {
    // Validate environment variables
    const requiredEnvVars = ['RPC_URL', 'PRIVATE_KEY', 'ORACLE_CONTRACT_ADDRESS'];
    const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);
    
    if (missingVars.length > 0) {
        console.error('❌ Missing required environment variables:', missingVars.join(', '));
        console.error('Please check your .env file');
        process.exit(1);
    }

    const oracle = new QRNGOracle();
    await oracle.initialize();
    global.oracleInstance = oracle; // Store for cleanup
    
    // Parse command line arguments
    const args = process.argv.slice(2);
    const command = args[0];
    
    switch (command) {
        case 'monitor':
            await oracle.monitorAndFulfillRequests();
            break;
            
        case 'fulfill':
            const requestId = parseInt(args[1]);
            if (isNaN(requestId)) {
                console.error('❌ Please provide a valid request ID');
                process.exit(1);
            }
            await oracle.processSpecificRequest(requestId);
            break;
            
        case 'test':
            console.log('🧪 Testing quantum randomness fetch...');
            const randomValue = await oracle.fetchQuantumRandomness();
            console.log('✅ Test successful! Random value:', randomValue);
            break;
            
        default:
            console.log('Usage:');
            console.log('  node qrng-fetch.js monitor     - Monitor for new requests');
            console.log('  node qrng-fetch.js fulfill <id> - Fulfill specific request');
            console.log('  node qrng-fetch.js test        - Test quantum randomness fetch');
            break;
    }
}

// Handle graceful shutdown
process.on('SIGINT', () => {
    console.log('\n👋 Shutting down gracefully...');
    // Clean up event listeners if oracle instance exists
    if (global.oracleInstance && global.oracleInstance.oracleContract) {
        global.oracleInstance.oracleContract.removeAllListeners();
    }
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('\n👋 Shutting down gracefully...');
    // Clean up event listeners if oracle instance exists
    if (global.oracleInstance && global.oracleInstance.oracleContract) {
        global.oracleInstance.oracleContract.removeAllListeners();
    }
    process.exit(0);
});

// Run the script
if (require.main === module) {
    main().catch(console.error);
}

module.exports = QRNGOracle; 