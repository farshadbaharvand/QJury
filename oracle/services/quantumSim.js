const axios = require('axios');

/**
 * Quantum Randomness Simulation Service
 * 
 * This service provides mock quantum randomness for testing purposes.
 * In production, this would be replaced with real quantum randomness from ANU QRNG API.
 */
class QuantumSimService {
    constructor() {
        this.apiUrl = 'https://qrng.anu.edu.au/API/jsonI.php?length=1&type=uint8';
        this.fallbackMode = false;
        this.requestCount = 0;
    }

    /**
     * Fetch quantum randomness from ANU QRNG API
     * Falls back to cryptographically secure random if API fails
     * 
     * @returns {Promise<number>} Random number between 0-255
     */
    async fetchQuantumRandomness() {
        try {
            console.log('🌌 Fetching quantum randomness from ANU QRNG API...');
            
            const response = await axios.get(this.apiUrl, {
                timeout: 5000, // 5 second timeout
                headers: {
                    'User-Agent': 'QJury-QuantumSim/1.0'
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
            console.warn('⚠️  Quantum API failed, using fallback randomness:', error.message);
            this.fallbackMode = true;
            return this.generateFallbackRandomness();
        }
    }

    /**
     * Generate cryptographically secure random number as fallback
     * 
     * @returns {number} Random number between 0-255
     */
    generateFallbackRandomness() {
        const crypto = require('crypto');
        const randomBytes = crypto.randomBytes(1);
        const randomValue = randomBytes[0];
        
        console.log('🔄 Fallback randomness generated:', randomValue);
        return randomValue;
    }

    /**
     * Generate a sequence of quantum random numbers
     * 
     * @param {number} count - Number of random values to generate
     * @returns {Promise<number[]>} Array of random numbers
     */
    async generateRandomSequence(count = 10) {
        const sequence = [];
        
        for (let i = 0; i < count; i++) {
            const randomValue = await this.fetchQuantumRandomness();
            sequence.push(randomValue);
            
            // Small delay between requests to be respectful to the API
            if (i < count - 1) {
                await this.delay(100);
            }
        }
        
        return sequence;
    }

    /**
     * Generate random number within a specific range
     * 
     * @param {number} min - Minimum value (inclusive)
     * @param {number} max - Maximum value (inclusive)
     * @returns {Promise<number>} Random number in range
     */
    async generateRandomInRange(min, max) {
        const randomValue = await this.fetchQuantumRandomness();
        const range = max - min + 1;
        return min + (randomValue % range);
    }

    /**
     * Generate random bytes for cryptographic purposes
     * 
     * @param {number} length - Number of bytes to generate
     * @returns {Promise<Buffer>} Random bytes
     */
    async generateRandomBytes(length = 32) {
        const bytes = [];
        
        for (let i = 0; i < length; i++) {
            const randomValue = await this.fetchQuantumRandomness();
            bytes.push(randomValue);
        }
        
        return Buffer.from(bytes);
    }

    /**
     * Test the quantum randomness service
     * 
     * @returns {Promise<object>} Test results
     */
    async testService() {
        console.log('🧪 Testing quantum randomness service...');
        
        const startTime = Date.now();
        const results = {
            success: true,
            fallbackUsed: false,
            responseTime: 0,
            randomValues: [],
            errors: []
        };

        try {
            // Test single random value
            const singleValue = await this.fetchQuantumRandomness();
            results.randomValues.push(singleValue);
            
            // Test sequence generation
            const sequence = await this.generateRandomSequence(5);
            results.randomValues.push(...sequence);
            
            results.responseTime = Date.now() - startTime;
            results.fallbackUsed = this.fallbackMode;
            
            console.log('✅ Quantum service test completed successfully');
            console.log(`📊 Generated ${results.randomValues.length} random values`);
            console.log(`⏱️  Response time: ${results.responseTime}ms`);
            console.log(`🔄 Fallback used: ${results.fallbackUsed}`);
            
        } catch (error) {
            results.success = false;
            results.errors.push(error.message);
            console.error('❌ Quantum service test failed:', error.message);
        }

        return results;
    }

    /**
     * Get service statistics
     * 
     * @returns {object} Service statistics
     */
    getStats() {
        return {
            requestCount: this.requestCount,
            fallbackMode: this.fallbackMode,
            apiUrl: this.apiUrl,
            timestamp: new Date().toISOString()
        };
    }

    /**
     * Reset service state
     */
    reset() {
        this.requestCount = 0;
        this.fallbackMode = false;
    }

    /**
     * Utility function to add delay
     * 
     * @param {number} ms - Milliseconds to delay
     * @returns {Promise<void>}
     */
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

// Export the service
module.exports = QuantumSimService;

// If running directly, perform a test
if (require.main === module) {
    const quantumService = new QuantumSimService();
    
    quantumService.testService()
        .then(results => {
            console.log('\n📋 Test Results:');
            console.log(JSON.stringify(results, null, 2));
            process.exit(results.success ? 0 : 1);
        })
        .catch(error => {
            console.error('❌ Test failed:', error);
            process.exit(1);
        });
}