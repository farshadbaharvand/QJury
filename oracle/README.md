# QJury Oracle Web Interface

This directory contains the web interface for the QJury Oracle system, providing a modern dashboard to monitor disputes and quantum randomness requests.

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ and npm
- QJury smart contracts deployed
- Environment variables configured

### Installation
```bash
# Install dependencies
npm install

# Set up environment variables
cp ../env.example ../.env
# Edit .env with your configuration
```

### Running the Web Interface
```bash
# Start the web interface
npm run ui

# Start in development mode (with auto-reload)
npm run ui:dev
```

The web interface will be available at `http://localhost:3000`

## 📊 Features

### Dashboard Overview
- **Network Status**: Real-time connection status to Ethereum network
- **Dispute Monitoring**: View all disputes with their current status
- **Quantum Randomness**: Monitor quantum randomness requests and fulfillments
- **Real-time Updates**: Auto-refresh every 30 seconds

### Dispute Management
- View dispute details including creator, fees, and voting status
- Monitor juror assignment and voting progress
- Track dispute resolution and reward distribution

### Quantum Randomness
- View quantum randomness request details
- Monitor request fulfillment status
- Test quantum randomness generation

## 🔧 API Endpoints

### Core Endpoints
- `GET /` - Main dashboard
- `GET /api/status` - System status and network info
- `GET /api/disputes` - List all disputes
- `GET /api/disputes/:id` - Get specific dispute details
- `GET /api/requests/:id` - Get quantum randomness request details

### Quantum Randomness API
- `GET /api/quantum/status` - Quantum service status
- `GET /api/quantum/random` - Get single quantum random number
- `GET /api/quantum/sequence?count=N` - Get sequence of random numbers
- `POST /api/quantum/range` - Get random number in range
- `GET /api/quantum/test` - Test quantum service
- `GET /api/quantum/health` - Health check

## 🎨 UI Components

### Frontend Structure
```
oracle/
├── public/
│   ├── index.html      # Main dashboard HTML
│   └── app.js          # Frontend JavaScript
├── routes/
│   └── quantum.js      # Quantum API routes
├── services/
│   └── quantumSim.js   # Quantum randomness service
└── index.js            # Express server
```

### Key Features
- **Responsive Design**: Works on desktop and mobile devices
- **Real-time Updates**: Auto-refresh and live status indicators
- **Search & Filter**: Find disputes by ID or creator address
- **Modal Dialogs**: Detailed views without page navigation
- **Error Handling**: Graceful error display and recovery

## 🧪 Testing

### Run UI Tests
```bash
# Test the web interface
npm run test:ui

# Test quantum service directly
npm run test:quantum
```

### Manual Testing
1. Start the web interface: `npm run ui`
2. Open browser to `http://localhost:3000`
3. Test the following features:
   - Dashboard loading
   - Tab switching
   - Dispute search
   - Quantum randomness requests
   - Modal dialogs

## 🔧 Configuration

### Environment Variables
```env
# Required
RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
ORACLE_CONTRACT_ADDRESS=0x1234567890123456789012345678901234567890
DISPUTE_CONTRACT_ADDRESS=0x1234567890123456789012345678901234567890

# Optional
PORT=3000
ETHERSCAN_URL=https://etherscan.io
CHAIN_ID=1
```

### Contract Addresses
Make sure the following contracts are deployed and configured:
- `QuantumRandomOracle` - For quantum randomness
- `QJuryDispute` - For dispute management
- `QJuryRegistry` - For juror management

## 🐛 Troubleshooting

### Common Issues

1. **Connection Error**
   - Check RPC_URL in .env file
   - Verify network connectivity
   - Ensure contract addresses are correct

2. **No Disputes Showing**
   - Verify DISPUTE_CONTRACT_ADDRESS is set
   - Check if contracts are deployed
   - Ensure contracts have the correct ABI

3. **Quantum Service Not Working**
   - Check internet connectivity
   - Verify ANU QRNG API is accessible
   - Service will fall back to crypto.randomBytes if needed

4. **UI Not Loading**
   - Check if port 3000 is available
   - Verify all dependencies are installed
   - Check browser console for errors

### Debug Mode
```bash
# Start with debug logging
DEBUG=* npm run ui

# Check logs
tail -f logs/oracle.log
```

## 📈 Performance

### Optimization Tips
- Use production build for better performance
- Enable gzip compression
- Use CDN for static assets
- Implement caching for API responses

### Monitoring
- Monitor API response times
- Track quantum randomness generation speed
- Watch for failed requests
- Monitor memory usage

## 🔒 Security

### Best Practices
- Use HTTPS in production
- Validate all API inputs
- Implement rate limiting
- Use environment variables for secrets
- Regular security updates

### Access Control
- Consider implementing authentication for admin features
- Restrict API access as needed
- Monitor for suspicious activity

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔗 Links

- [QJury Main Documentation](../README.md)
- [Quantum Integration Guide](../QUANTUM_INTEGRATION.md)
- [Smart Contract Documentation](../docs/)