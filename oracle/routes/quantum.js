const express = require('express');
const QuantumSimService = require('../services/quantumSim');

const router = express.Router();
const quantumService = new QuantumSimService();

/**
 * @route GET /api/quantum/status
 * @desc Get quantum service status and statistics
 * @access Public
 */
router.get('/status', async (req, res) => {
    try {
        const stats = quantumService.getStats();
        res.json({
            success: true,
            data: {
                ...stats,
                service: 'Quantum Randomness Service',
                version: '1.0.0',
                endpoints: [
                    'GET /api/quantum/status',
                    'GET /api/quantum/random',
                    'GET /api/quantum/sequence',
                    'POST /api/quantum/range',
                    'GET /api/quantum/test'
                ]
            }
        });
    } catch (error) {
        console.error('Error getting quantum status:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to get quantum service status'
        });
    }
});

/**
 * @route GET /api/quantum/random
 * @desc Get a single quantum random number
 * @access Public
 */
router.get('/random', async (req, res) => {
    try {
        const randomValue = await quantumService.fetchQuantumRandomness();
        
        res.json({
            success: true,
            data: {
                randomValue,
                timestamp: new Date().toISOString(),
                source: quantumService.fallbackMode ? 'fallback' : 'quantum',
                range: '0-255'
            }
        });
    } catch (error) {
        console.error('Error generating quantum random:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to generate quantum random number'
        });
    }
});

/**
 * @route GET /api/quantum/sequence
 * @desc Get a sequence of quantum random numbers
 * @access Public
 */
router.get('/sequence', async (req, res) => {
    try {
        const count = parseInt(req.query.count) || 10;
        
        // Validate count parameter
        if (count < 1 || count > 100) {
            return res.status(400).json({
                success: false,
                error: 'Count must be between 1 and 100'
            });
        }

        const sequence = await quantumService.generateRandomSequence(count);
        
        res.json({
            success: true,
            data: {
                sequence,
                count: sequence.length,
                timestamp: new Date().toISOString(),
                source: quantumService.fallbackMode ? 'fallback' : 'quantum',
                range: '0-255'
            }
        });
    } catch (error) {
        console.error('Error generating quantum sequence:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to generate quantum random sequence'
        });
    }
});

/**
 * @route POST /api/quantum/range
 * @desc Get a quantum random number within a specified range
 * @access Public
 */
router.post('/range', async (req, res) => {
    try {
        const { min, max } = req.body;
        
        // Validate input parameters
        if (typeof min !== 'number' || typeof max !== 'number') {
            return res.status(400).json({
                success: false,
                error: 'min and max must be numbers'
            });
        }
        
        if (min >= max) {
            return res.status(400).json({
                success: false,
                error: 'min must be less than max'
            });
        }
        
        if (min < 0 || max > 255) {
            return res.status(400).json({
                success: false,
                error: 'Range must be between 0 and 255'
            });
        }

        const randomValue = await quantumService.generateRandomInRange(min, max);
        
        res.json({
            success: true,
            data: {
                randomValue,
                min,
                max,
                timestamp: new Date().toISOString(),
                source: quantumService.fallbackMode ? 'fallback' : 'quantum'
            }
        });
    } catch (error) {
        console.error('Error generating quantum random in range:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to generate quantum random number in range'
        });
    }
});

/**
 * @route GET /api/quantum/test
 * @desc Test the quantum randomness service
 * @access Public
 */
router.get('/test', async (req, res) => {
    try {
        const testResults = await quantumService.testService();
        
        res.json({
            success: testResults.success,
            data: testResults,
            message: testResults.success ? 
                'Quantum service test completed successfully' : 
                'Quantum service test failed'
        });
    } catch (error) {
        console.error('Error testing quantum service:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to test quantum service'
        });
    }
});

/**
 * @route POST /api/quantum/reset
 * @desc Reset the quantum service state
 * @access Public
 */
router.post('/reset', async (req, res) => {
    try {
        quantumService.reset();
        
        res.json({
            success: true,
            message: 'Quantum service state reset successfully',
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('Error resetting quantum service:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to reset quantum service'
        });
    }
});

/**
 * @route GET /api/quantum/health
 * @desc Health check endpoint for quantum service
 * @access Public
 */
router.get('/health', async (req, res) => {
    try {
        // Quick test to ensure service is working
        const randomValue = await quantumService.fetchQuantumRandomness();
        
        res.json({
            success: true,
            status: 'healthy',
            timestamp: new Date().toISOString(),
            testValue: randomValue,
            fallbackMode: quantumService.fallbackMode
        });
    } catch (error) {
        console.error('Quantum service health check failed:', error);
        res.status(503).json({
            success: false,
            status: 'unhealthy',
            error: 'Quantum service is not responding',
            timestamp: new Date().toISOString()
        });
    }
});

module.exports = router;