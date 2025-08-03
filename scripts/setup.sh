#!/bin/bash

# QJury Quantum Randomness System Setup Script
# This script helps you set up and deploy the complete QJury system

set -e

echo "🚀 QJury Quantum Randomness System Setup"
echo "========================================"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if required tools are installed
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install Node.js 16+ from https://nodejs.org/"
        exit 1
    fi
    
    node_version=$(node --version | cut -d 'v' -f 2 | cut -d '.' -f 1)
    if [ "$node_version" -lt 16 ]; then
        print_error "Node.js version 16+ is required. Current version: $(node --version)"
        exit 1
    fi
    
    # Check Foundry
    if ! command -v forge &> /dev/null; then
        print_warning "Foundry is not installed. Installing Foundry..."
        curl -L https://foundry.paradigm.xyz | bash
        source ~/.bashrc
        foundryup
    fi
    
    print_status "Prerequisites check complete"
}

# Install dependencies
install_dependencies() {
    print_info "Installing dependencies..."
    
    # Install Node.js dependencies
    if [ -f "package.json" ]; then
        npm install
        print_status "Node.js dependencies installed"
    fi
    
    # Install Foundry dependencies
    if [ -f "foundry.toml" ]; then
        forge install
        print_status "Foundry dependencies installed"
    fi
}

# Setup environment
setup_environment() {
    print_info "Setting up environment..."
    
    if [ ! -f ".env" ]; then
        cp .env.example .env
        print_warning "Created .env file from .env.example"
        print_warning "Please edit .env file with your configuration before proceeding"
        print_info "Required variables:"
        echo "  - PRIVATE_KEY: Your wallet private key"
        echo "  - RPC_URL: Your Ethereum RPC endpoint"
        echo "  - ETHERSCAN_API_KEY: For contract verification (optional)"
        echo ""
        read -p "Press Enter after configuring .env file..."
    else
        print_status "Environment file already exists"
    fi
}

# Compile contracts
compile_contracts() {
    print_info "Compiling smart contracts..."
    
    forge build
    if [ $? -eq 0 ]; then
        print_status "Smart contracts compiled successfully"
    else
        print_error "Contract compilation failed"
        exit 1
    fi
}

# Run tests
run_tests() {
    print_info "Running test suite..."
    
    echo "Running basic deployment test..."
    forge test --match-test testQuantumOracleDeployment -v
    
    if [ $? -eq 0 ]; then
        print_status "Basic tests passed"
        
        read -p "Run full test suite? (y/N): " run_full_tests
        if [[ $run_full_tests =~ ^[Yy]$ ]]; then
            forge test -v
            if [ $? -eq 0 ]; then
                print_status "All tests passed ✨"
            else
                print_warning "Some tests failed. Check output above."
            fi
        fi
    else
        print_error "Basic tests failed"
        exit 1
    fi
}

# Test quantum API connectivity
test_quantum_api() {
    print_info "Testing ANU QRNG API connectivity..."
    
    # Test if we can reach the quantum API
    response=$(curl -s "https://qrng.anu.edu.au/API/jsonI.php?length=1&type=uint8" | jq '.success' 2>/dev/null)
    
    if [ "$response" = "true" ]; then
        print_status "Quantum randomness API is accessible"
    else
        print_warning "Could not test quantum API (might be temporarily unavailable)"
        print_info "The system will work with fallback randomness if needed"
    fi
}

# Deploy contracts (optional)
deploy_contracts() {
    read -p "Deploy contracts to blockchain? (y/N): " deploy_choice
    
    if [[ $deploy_choice =~ ^[Yy]$ ]]; then
        print_info "Deploying contracts..."
        
        # Check if environment is properly configured
        source .env
        
        if [ -z "$PRIVATE_KEY" ] || [ -z "$RPC_URL" ]; then
            print_error "PRIVATE_KEY and RPC_URL must be set in .env file"
            exit 1
        fi
        
        print_info "Simulating deployment..."
        node scripts/deploy.js
        
        print_info "For actual deployment, run:"
        echo "  npm run deploy"
        echo "or"
        echo "  forge script script/Deploy.s.sol --rpc-url \$RPC_URL --broadcast"
    fi
}

# Setup quantum oracle service
setup_oracle_service() {
    read -p "Set up quantum oracle service? (y/N): " oracle_choice
    
    if [[ $oracle_choice =~ ^[Yy]$ ]]; then
        print_info "Setting up quantum randomness fetcher..."
        
        # Test the Node.js script
        print_info "Testing quantum randomness fetcher..."
        if npm run test-api; then
            print_status "Quantum fetcher is working correctly"
            
            print_info "To start the quantum oracle service:"
            echo "  npm start"
            echo ""
            print_info "Or run in background:"
            echo "  nohup npm start > oracle.log 2>&1 &"
        else
            print_warning "Quantum fetcher test failed. Check your configuration."
        fi
    fi
}

# Show final instructions
show_final_instructions() {
    echo ""
    echo "🎉 QJury Setup Complete!"
    echo "======================="
    echo ""
    print_info "Next steps:"
    echo "1. Deploy contracts: npm run deploy"
    echo "2. Update .env with deployed contract addresses"
    echo "3. Start quantum oracle: npm start"
    echo "4. Build your frontend using Thirdweb SDK"
    echo ""
    print_info "Useful commands:"
    echo "• Test contracts: npm run test"
    echo "• Check oracle auth: npm run check-auth"
    echo "• View pending requests: npm run check-pending"
    echo "• Test quantum API: npm run test-api"
    echo ""
    print_info "Documentation:"
    echo "• Project README: README.md"
    echo "• Contract docs: In contracts/ directory"
    echo "• Test examples: In test/ directory"
    echo ""
    print_status "Happy building with quantum randomness! 🌌"
}

# Main execution flow
main() {
    check_prerequisites
    install_dependencies
    setup_environment
    compile_contracts
    run_tests
    test_quantum_api
    deploy_contracts
    setup_oracle_service
    show_final_instructions
}

# Run main function
main