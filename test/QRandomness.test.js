const axios = require('axios');

// Test the ANU QRNG API directly
async function testQuantumRandomness() {
    const QRNG_API_URL = 'https://qrng.anu.edu.au/API/jsonI.php?length=1&type=uint8';
    
    try {
        console.log('🧪 Testing ANU QRNG API directly...');
        
        const response = await axios.get(QRNG_API_URL, {
            timeout: 10000,
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
        console.log('✅ Quantum randomness test successful!');
        console.log('📊 Random value:', randomValue);
        console.log('📋 Response data:', data);
        
        return randomValue;
    } catch (error) {
        console.error('❌ Quantum randomness test failed:', error.message);
        if (error.response) {
            console.error('Response status:', error.response.status);
            console.error('Response data:', error.response.data);
        }
        throw error;
    }
}

// Run the test
if (require.main === module) {
    testQuantumRandomness()
        .then(() => {
            console.log('🎉 All tests passed!');
            process.exit(0);
        })
        .catch((error) => {
            console.error('💥 Tests failed:', error.message);
            process.exit(1);
        });
}

module.exports = { testQuantumRandomness };