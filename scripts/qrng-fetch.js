#!/usr/bin/env node

/**
 * QJury Quantum Randomness Fetcher
 * Fetches real quantum randomness from ANU QRNG API and submits to oracle contract
 */

const https = require('https');
const { ethers } = require('ethers');
require('dotenv').config();

// Configuration
const ANU_QRNG_API = 'https://qrng.anu.edu.au/API/jsonI.php?length=1&type=uint8';
const POLL_INTERVAL = 30000; // 30 seconds
const MAX_RETRIES = 3;
const RETRY_DELAY = 5000; // 5 seconds

// Contract ABI for QuantumRandomOracle (simplified)
const ORACLE_ABI = [
    "function fulfillRandomness(uint256 requestId, uint256 randomValue) external",
    "function getPendingRequests() external view returns (uint256[])",
    "function getRequest(uint256 requestId) external view returns (tuple(uint256 requestId, address requester, uint256 timestamp, bool fulfilled, uint256 randomValue, uint256 blockNumber))",
    "function authorizedOracles(address) external view returns (bool)",
    "event RandomnessRequested(uint256 indexed requestId, address indexed requester, uint256 timestamp, uint256 blockNumber)",
    "event RandomnessFulfilled(uint256 indexed requestId, uint256 randomValue, address indexed oracle, uint256 timestamp)"
];

class QuantumRandomnessFetcher {
    constructor() {
        this.validateEnvironment();
        this.setupProvider();
        this.setupContracts();
        this.isRunning = false;
    }

    validateEnvironment() {
        const required = ['PRIVATE_KEY', 'RPC_URL', 'ORACLE_CONTRACT_ADDRESS'];
        const missing = required.filter(key => !process.env[key]);
        
        if (missing.length > 0) {
            console.error('❌ Missing required environment variables:', missing);
            console.error('Please create a .env file with:');
            console.error('PRIVATE_KEY=your_private_key');
            console.error('RPC_URL=your_rpc_endpoint');
            console.error('ORACLE_CONTRACT_ADDRESS=deployed_oracle_address');
            process.exit(1);
        }
    }

    setupProvider() {
        try {
            this.provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
            this.wallet = new ethers.Wallet(process.env.PRIVATE_KEY, this.provider);
            console.log('✅ Connected to blockchain with wallet:', this.wallet.address);
        } catch (error) {
            console.error('❌ Failed to setup provider:', error.message);
            process.exit(1);
        }
    }

    setupContracts() {
        try {
            this.oracleContract = new ethers.Contract(
                process.env.ORACLE_CONTRACT_ADDRESS,
                ORACLE_ABI,
                this.wallet
            );
            console.log('✅ Oracle contract initialized at:', process.env.ORACLE_CONTRACT_ADDRESS);
        } catch (error) {
            console.error('❌ Failed to setup contracts:', error.message);
            process.exit(1);
        }
    }

    async fetchQuantumRandomness() {
        return new Promise((resolve, reject) => {
            const timeout = setTimeout(() => {
                reject(new Error('API request timeout'));
            }, 10000);

            https.get(ANU_QRNG_API, (res) => {
                let data = '';
                
                res.on('data', (chunk) => {
                    data += chunk;
                });
                
                res.on('end', () => {
                    clearTimeout(timeout);
                    try {
                        const response = JSON.parse(data);
                        
                        if (response.success && response.data && response.data.length > 0) {
                            // Convert uint8 to uint256 by combining with additional entropy
                            const quantumByte = response.data[0];
                            const timestamp = Date.now();
                            const combined = ethers.solidityPackedKeccak256(
                                ['uint8', 'uint256', 'string'],
                                [quantumByte, timestamp, 'ANU_QUANTUM']
                            );
                            const randomValue = BigInt(combined);
                            
                            resolve({
                                originalValue: quantumByte,
                                expandedValue: randomValue,
                                timestamp: timestamp,
                                success: true
                            });
                        } else {
                            reject(new Error('Invalid API response format'));
                        }
                    } catch (error) {
                        reject(new Error(`Failed to parse API response: ${error.message}`));
                    }
                });
            }).on('error', (error) => {
                clearTimeout(timeout);
                reject(new Error(`API request failed: ${error.message}`));
            });
        });
    }

    async getPendingRequests() {
        try {
            const pendingRequests = await this.oracleContract.getPendingRequests();
            return pendingRequests.map(id => id.toString());
        } catch (error) {
            console.error('❌ Failed to get pending requests:', error.message);
            return [];
        }
    }

    async fulfillRandomnessRequest(requestId, randomValue) {
        let attempt = 0;
        
        while (attempt < MAX_RETRIES) {
            try {
                console.log(`🎲 Fulfilling request ${requestId} with quantum value: ${randomValue.toString()}`);
                
                // Estimate gas first
                const estimatedGas = await this.oracleContract.fulfillRandomness.estimateGas(
                    requestId, 
                    randomValue
                );
                
                const tx = await this.oracleContract.fulfillRandomness(
                    requestId, 
                    randomValue,
                    {
                        gasLimit: estimatedGas + BigInt(50000), // Add buffer
                        gasPrice: await this.provider.getFeeData().then(fee => fee.gasPrice)
                    }
                );
                
                console.log(`📡 Transaction sent: ${tx.hash}`);
                const receipt = await tx.wait();
                
                if (receipt.status === 1) {
                    console.log(`✅ Request ${requestId} fulfilled successfully in block ${receipt.blockNumber}`);
                    return true;
                } else {
                    throw new Error('Transaction failed');
                }
                
            } catch (error) {
                attempt++;
                console.error(`❌ Attempt ${attempt} failed for request ${requestId}:`, error.message);
                
                if (attempt < MAX_RETRIES) {
                    console.log(`⏳ Retrying in ${RETRY_DELAY/1000} seconds...`);
                    await new Promise(resolve => setTimeout(resolve, RETRY_DELAY));
                }
            }
        }
        
        console.error(`❌ Failed to fulfill request ${requestId} after ${MAX_RETRIES} attempts`);
        return false;
    }

    async processPendingRequests() {
        try {
            const pendingRequests = await this.getPendingRequests();
            
            if (pendingRequests.length === 0) {
                console.log('📋 No pending randomness requests');
                return;
            }
            
            console.log(`📋 Found ${pendingRequests.length} pending requests:`, pendingRequests);
            
            for (const requestId of pendingRequests) {
                try {
                    // Fetch quantum randomness
                    console.log(`🔬 Fetching quantum randomness for request ${requestId}...`);
                    const quantumData = await this.fetchQuantumRandomness();
                    
                    console.log(`🎯 Quantum data received:`, {
                        original: quantumData.originalValue,
                        expanded: quantumData.expandedValue.toString(),
                        timestamp: new Date(quantumData.timestamp).toISOString()
                    });
                    
                    // Fulfill the request
                    await this.fulfillRandomnessRequest(requestId, quantumData.expandedValue);
                    
                    // Small delay between requests to avoid rate limiting
                    await new Promise(resolve => setTimeout(resolve, 2000));
                    
                } catch (error) {
                    console.error(`❌ Failed to process request ${requestId}:`, error.message);
                }
            }
            
        } catch (error) {
            console.error('❌ Error processing pending requests:', error.message);
        }
    }

    async checkAuthorization() {
        try {
            const isAuthorized = await this.oracleContract.authorizedOracles(this.wallet.address);
            if (!isAuthorized) {
                console.error('❌ Wallet is not authorized as an oracle');
                console.error('Please authorize this address in the oracle contract:', this.wallet.address);
                return false;
            }
            console.log('✅ Wallet is authorized as oracle');
            return true;
        } catch (error) {
            console.error('❌ Failed to check authorization:', error.message);
            return false;
        }
    }

    async start() {
        console.log('🚀 Starting QJury Quantum Randomness Fetcher');
        console.log('🔗 Quantum source: ANU QRNG API');
        console.log(`⏰ Poll interval: ${POLL_INTERVAL/1000} seconds`);
        console.log('==========================================');
        
        // Check authorization
        const isAuthorized = await this.checkAuthorization();
        if (!isAuthorized) {
            process.exit(1);
        }
        
        // Test API connectivity
        try {
            console.log('🧪 Testing ANU QRNG API connectivity...');
            const testData = await this.fetchQuantumRandomness();
            console.log('✅ API test successful:', {
                original: testData.originalValue,
                expanded: testData.expandedValue.toString().substring(0, 20) + '...'
            });
        } catch (error) {
            console.error('❌ API test failed:', error.message);
            console.error('Continuing anyway, will retry on actual requests...');
        }
        
        this.isRunning = true;
        
        // Setup event listeners for new requests
        this.oracleContract.on('RandomnessRequested', (requestId, requester, timestamp, blockNumber) => {
            console.log(`🔔 New randomness request: ${requestId} from ${requester}`);
        });
        
        // Main processing loop
        while (this.isRunning) {
            await this.processPendingRequests();
            await new Promise(resolve => setTimeout(resolve, POLL_INTERVAL));
        }
    }

    stop() {
        console.log('🛑 Stopping Quantum Randomness Fetcher...');
        this.isRunning = false;
        this.oracleContract.removeAllListeners();
    }
}

// Handle graceful shutdown
process.on('SIGINT', () => {
    console.log('\n📡 Received shutdown signal...');
    if (global.fetcher) {
        global.fetcher.stop();
    }
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('\n📡 Received termination signal...');
    if (global.fetcher) {
        global.fetcher.stop();
    }
    process.exit(0);
});

// CLI interface
if (require.main === module) {
    const command = process.argv[2];
    
    if (command === 'test') {
        // Test mode - fetch one random value and exit
        console.log('🧪 Test mode: Fetching single quantum random value...');
        const fetcher = new QuantumRandomnessFetcher();
        
        fetcher.fetchQuantumRandomness()
            .then(data => {
                console.log('✅ Quantum randomness test successful:');
                console.log(`   Original uint8: ${data.originalValue}`);
                console.log(`   Expanded uint256: ${data.expandedValue.toString()}`);
                console.log(`   Timestamp: ${new Date(data.timestamp).toISOString()}`);
                process.exit(0);
            })
            .catch(error => {
                console.error('❌ Test failed:', error.message);
                process.exit(1);
            });
    } else if (command === 'auth') {
        // Check authorization status
        console.log('🔐 Checking oracle authorization...');
        const fetcher = new QuantumRandomnessFetcher();
        fetcher.checkAuthorization().then(() => process.exit(0));
    } else if (command === 'pending') {
        // Show pending requests
        console.log('📋 Checking pending requests...');
        const fetcher = new QuantumRandomnessFetcher();
        fetcher.getPendingRequests()
            .then(requests => {
                console.log(`Found ${requests.length} pending requests:`, requests);
                process.exit(0);
            })
            .catch(error => {
                console.error('❌ Failed to get pending requests:', error.message);
                process.exit(1);
            });
    } else {
        // Normal operation mode
        global.fetcher = new QuantumRandomnessFetcher();
        global.fetcher.start().catch(error => {
            console.error('❌ Fatal error:', error.message);
            process.exit(1);
        });
    }
}

module.exports = QuantumRandomnessFetcher;