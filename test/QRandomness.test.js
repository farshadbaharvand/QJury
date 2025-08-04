const QuantumSimService = require('../oracle/services/quantumSim');
const axios = require('axios');

/**
 * Quantum Randomness Test Suite
 * 
 * This test suite validates the quantum randomness functionality
 * and ensures the UI components work correctly with the quantum service.
 */
class QuantumRandomnessTest {
    constructor() {
        this.quantumService = new QuantumSimService();
        this.baseUrl = 'http://localhost:3000';
        this.testResults = {
            passed: 0,
            failed: 0,
            total: 0,
            details: []
        };
    }

    /**
     * Run all tests
     */
    async runAllTests() {
        console.log('🧪 Starting Quantum Randomness Test Suite...\n');
        
        await this.testQuantumService();
        await this.testAPIEndpoints();
        await this.testUIComponents();
        await this.testIntegration();
        
        this.printResults();
    }

    /**
     * Test the quantum service directly
     */
    async testQuantumService() {
        console.log('📊 Testing Quantum Service...');
        
        // Test single random value
        await this.runTest('Single Random Value', async () => {
            const value = await this.quantumService.fetchQuantumRandomness();
            return value >= 0 && value <= 255;
        });

        // Test sequence generation
        await this.runTest('Random Sequence', async () => {
            const sequence = await this.quantumService.generateRandomSequence(5);
            return sequence.length === 5 && sequence.every(v => v >= 0 && v <= 255);
        });

        // Test range generation
        await this.runTest('Random in Range', async () => {
            const value = await this.quantumService.generateRandomInRange(10, 20);
            return value >= 10 && value <= 20;
        });

        // Test service statistics
        await this.runTest('Service Statistics', async () => {
            const stats = this.quantumService.getStats();
            return stats && typeof stats.requestCount === 'number';
        });
    }

    /**
     * Test API endpoints
     */
    async testAPIEndpoints() {
        console.log('\n🌐 Testing API Endpoints...');
        
        // Test quantum status endpoint
        await this.runTest('Quantum Status API', async () => {
            try {
                const response = await axios.get(`${this.baseUrl}/api/quantum/status`);
                return response.status === 200 && response.data.success;
            } catch (error) {
                return false;
            }
        });

        // Test random endpoint
        await this.runTest('Random API', async () => {
            try {
                const response = await axios.get(`${this.baseUrl}/api/quantum/random`);
                return response.status === 200 && 
                       response.data.success && 
                       response.data.data.randomValue >= 0 && 
                       response.data.data.randomValue <= 255;
            } catch (error) {
                return false;
            }
        });

        // Test sequence endpoint
        await this.runTest('Sequence API', async () => {
            try {
                const response = await axios.get(`${this.baseUrl}/api/quantum/sequence?count=3`);
                return response.status === 200 && 
                       response.data.success && 
                       response.data.data.sequence.length === 3;
            } catch (error) {
                return false;
            }
        });

        // Test range endpoint
        await this.runTest('Range API', async () => {
            try {
                const response = await axios.post(`${this.baseUrl}/api/quantum/range`, {
                    min: 5,
                    max: 15
                });
                return response.status === 200 && 
                       response.data.success && 
                       response.data.data.randomValue >= 5 && 
                       response.data.data.randomValue <= 15;
            } catch (error) {
                return false;
            }
        });

        // Test health endpoint
        await this.runTest('Health API', async () => {
            try {
                const response = await axios.get(`${this.baseUrl}/api/quantum/health`);
                return response.status === 200 && response.data.success;
            } catch (error) {
                return false;
            }
        });
    }

    /**
     * Test UI components
     */
    async testUIComponents() {
        console.log('\n🎨 Testing UI Components...');
        
        // Test main dashboard endpoint
        await this.runTest('Dashboard HTML', async () => {
            try {
                const response = await axios.get(`${this.baseUrl}/`);
                return response.status === 200 && 
                       response.data.includes('QJury Oracle Dashboard') &&
                       response.data.includes('app.js');
            } catch (error) {
                return false;
            }
        });

        // Test static files
        await this.runTest('Static Files', async () => {
            try {
                const response = await axios.get(`${this.baseUrl}/app.js`);
                return response.status === 200 && 
                       response.data.includes('QJuryDashboard');
            } catch (error) {
                return false;
            }
        });

        // Test API status endpoint
        await this.runTest('API Status', async () => {
            try {
                const response = await axios.get(`${this.baseUrl}/api/status`);
                return response.status === 200 && response.data.status === 'connected';
            } catch (error) {
                return false;
            }
        });
    }

    /**
     * Test integration scenarios
     */
    async testIntegration() {
        console.log('\n🔗 Testing Integration...');
        
        // Test end-to-end workflow
        await this.runTest('End-to-End Workflow', async () => {
            try {
                // 1. Get quantum random value
                const randomResponse = await axios.get(`${this.baseUrl}/api/quantum/random`);
                if (!randomResponse.data.success) return false;
                
                // 2. Check service status
                const statusResponse = await axios.get(`${this.baseUrl}/api/quantum/status`);
                if (!statusResponse.data.success) return false;
                
                // 3. Verify dashboard loads
                const dashboardResponse = await axios.get(`${this.baseUrl}/`);
                if (dashboardResponse.status !== 200) return false;
                
                return true;
            } catch (error) {
                return false;
            }
        });

        // Test error handling
        await this.runTest('Error Handling', async () => {
            try {
                // Test invalid range
                const response = await axios.post(`${this.baseUrl}/api/quantum/range`, {
                    min: 20,
                    max: 10
                });
                return response.status === 400; // Should return error for invalid range
            } catch (error) {
                return error.response && error.response.status === 400;
            }
        });

        // Test fallback mode
        await this.runTest('Fallback Mode', async () => {
            try {
                // Reset service to test fallback
                this.quantumService.reset();
                
                // Simulate API failure by temporarily changing URL
                const originalUrl = this.quantumService.apiUrl;
                this.quantumService.apiUrl = 'https://invalid-url-that-will-fail.com';
                
                const value = await this.quantumService.fetchQuantumRandomness();
                
                // Restore original URL
                this.quantumService.apiUrl = originalUrl;
                
                return value >= 0 && value <= 255; // Should still return valid value
            } catch (error) {
                return false;
            }
        });
    }

    /**
     * Run a single test
     */
    async runTest(testName, testFunction) {
        this.testResults.total++;
        
        try {
            const result = await testFunction();
            
            if (result) {
                this.testResults.passed++;
                console.log(`✅ ${testName}`);
                this.testResults.details.push({
                    name: testName,
                    status: 'PASSED',
                    error: null
                });
            } else {
                this.testResults.failed++;
                console.log(`❌ ${testName}`);
                this.testResults.details.push({
                    name: testName,
                    status: 'FAILED',
                    error: 'Test returned false'
                });
            }
        } catch (error) {
            this.testResults.failed++;
            console.log(`❌ ${testName} - ${error.message}`);
            this.testResults.details.push({
                name: testName,
                status: 'FAILED',
                error: error.message
            });
        }
    }

    /**
     * Print test results
     */
    printResults() {
        console.log('\n📋 Test Results Summary:');
        console.log('========================');
        console.log(`Total Tests: ${this.testResults.total}`);
        console.log(`Passed: ${this.testResults.passed}`);
        console.log(`Failed: ${this.testResults.failed}`);
        console.log(`Success Rate: ${((this.testResults.passed / this.testResults.total) * 100).toFixed(1)}%`);
        
        if (this.testResults.failed > 0) {
            console.log('\n❌ Failed Tests:');
            this.testResults.details
                .filter(test => test.status === 'FAILED')
                .forEach(test => {
                    console.log(`  - ${test.name}: ${test.error}`);
                });
        }
        
        console.log('\n🎯 Test Suite Complete!');
        
        if (this.testResults.failed === 0) {
            console.log('🎉 All tests passed! The quantum randomness system is working correctly.');
        } else {
            console.log('⚠️  Some tests failed. Please check the implementation.');
        }
    }

    /**
     * Test specific functionality
     */
    async testSpecificFunctionality() {
        console.log('\n🔧 Testing Specific Functionality...');
        
        // Test quantum randomness distribution
        await this.runTest('Randomness Distribution', async () => {
            const values = [];
            for (let i = 0; i < 100; i++) {
                const value = await this.quantumService.fetchQuantumRandomness();
                values.push(value);
            }
            
            // Check if values are distributed across the range
            const uniqueValues = new Set(values);
            return uniqueValues.size > 50; // Should have good distribution
        });

        // Test performance
        await this.runTest('Performance Test', async () => {
            const startTime = Date.now();
            await this.quantumService.generateRandomSequence(10);
            const endTime = Date.now();
            
            return (endTime - startTime) < 10000; // Should complete within 10 seconds
        });
    }
}

// Export the test class
module.exports = QuantumRandomnessTest;

// Run tests if this file is executed directly
if (require.main === module) {
    const testSuite = new QuantumRandomnessTest();
    
    testSuite.runAllTests()
        .then(() => {
            console.log('\n🏁 Test execution completed');
            process.exit(testSuite.testResults.failed === 0 ? 0 : 1);
        })
        .catch(error => {
            console.error('❌ Test execution failed:', error);
            process.exit(1);
        });
}