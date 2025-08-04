// QJury Oracle Dashboard JavaScript
class QJuryDashboard {
    constructor() {
        this.currentTab = 'disputes';
        this.disputes = [];
        this.init();
    }

    async init() {
        this.setupEventListeners();
        await this.checkConnection();
        await this.loadDisputes();
        this.startAutoRefresh();
    }

    setupEventListeners() {
        // Tab switching
        document.getElementById('disputes-tab').addEventListener('click', () => this.switchTab('disputes'));
        document.getElementById('requests-tab').addEventListener('click', () => this.switchTab('requests'));

        // Refresh buttons
        document.getElementById('refresh-btn').addEventListener('click', () => this.refreshAll());
        document.getElementById('refresh-disputes').addEventListener('click', () => this.loadDisputes());

        // Search functionality
        document.getElementById('dispute-search').addEventListener('input', (e) => this.filterDisputes(e.target.value));

        // Request fetching
        document.getElementById('fetch-request').addEventListener('click', () => this.fetchRequestDetails());

        // Modal management
        document.getElementById('close-modal').addEventListener('click', () => this.closeModal());
        document.getElementById('dispute-modal').addEventListener('click', (e) => {
            if (e.target.id === 'dispute-modal') this.closeModal();
        });

        // Enter key for request input
        document.getElementById('request-id-input').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') this.fetchRequestDetails();
        });
    }

    async checkConnection() {
        try {
            const response = await fetch('/api/status');
            const data = await response.json();
            
            if (data.status === 'connected') {
                this.updateConnectionStatus('connected');
                this.updateNetworkInfo(data);
            } else {
                this.updateConnectionStatus('error');
            }
        } catch (error) {
            console.error('Connection check failed:', error);
            this.updateConnectionStatus('error');
        }
    }

    updateConnectionStatus(status) {
        const statusElement = document.getElementById('connection-status');
        const indicator = statusElement.querySelector('.status-indicator');
        const text = statusElement.querySelector('span:last-child');

        indicator.className = 'status-indicator';
        
        switch (status) {
            case 'connected':
                indicator.classList.add('status-active');
                text.textContent = 'Connected';
                break;
            case 'error':
                indicator.classList.add('status-pending');
                text.textContent = 'Connection Error';
                break;
            default:
                indicator.classList.add('status-pending');
                text.textContent = 'Connecting...';
        }
    }

    updateNetworkInfo(data) {
        document.getElementById('network-name').textContent = data.network || 'Unknown Network';
    }

    async loadDisputes() {
        try {
            this.showLoading('disputes');
            const response = await fetch('/api/disputes');
            const data = await response.json();
            
            this.disputes = data.disputes || [];
            this.renderDisputes();
            this.updateDisputeCount(data.total);
        } catch (error) {
            console.error('Failed to load disputes:', error);
            this.showError('disputes', 'Failed to load disputes');
        }
    }

    renderDisputes() {
        const tbody = document.getElementById('disputes-tbody');
        
        if (this.disputes.length === 0) {
            tbody.innerHTML = `
                <tr>
                    <td colspan="5" class="px-6 py-4 text-center text-gray-500">
                        No disputes found
                    </td>
                </tr>
            `;
            return;
        }

        tbody.innerHTML = this.disputes.map(dispute => `
            <tr class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    #${dispute.id}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    ${this.shortenAddress(dispute.creator)}
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        dispute.resolved ? 'bg-gray-100 text-gray-800' : 'bg-green-100 text-green-800'
                    }">
                        <span class="status-indicator ${dispute.resolved ? 'status-resolved' : 'status-active'}"></span>
                        ${dispute.resolved ? 'Resolved' : 'Active'}
                    </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    ${this.formatTimestamp(dispute.votingEndTime)}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    <button onclick="dashboard.viewDisputeDetails(${dispute.id})" 
                            class="text-blue-600 hover:text-blue-900">
                        View Details
                    </button>
                </td>
            </tr>
        `).join('');
    }

    async viewDisputeDetails(disputeId) {
        try {
            const response = await fetch(`/api/disputes/${disputeId}`);
            const data = await response.json();
            
            if (response.ok) {
                this.showDisputeModal(data);
            } else {
                throw new Error(data.error || 'Failed to fetch dispute details');
            }
        } catch (error) {
            console.error('Failed to fetch dispute details:', error);
            alert('Failed to load dispute details: ' + error.message);
        }
    }

    showDisputeModal(data) {
        const modal = document.getElementById('dispute-modal');
        const content = document.getElementById('modal-content');
        
        content.innerHTML = `
            <div class="space-y-4">
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Dispute ID</label>
                        <p class="mt-1 text-sm text-gray-900">#${data.disputeId}</p>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Status</label>
                        <p class="mt-1 text-sm text-gray-900">
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                                data.dispute.resolved ? 'bg-gray-100 text-gray-800' : 'bg-green-100 text-green-800'
                            }">
                                ${data.dispute.resolved ? 'Resolved' : 'Active'}
                            </span>
                        </p>
                    </div>
                </div>
                
                <div>
                    <label class="block text-sm font-medium text-gray-700">Creator</label>
                    <p class="mt-1 text-sm text-gray-900 font-mono">${data.dispute.creator}</p>
                </div>
                
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Fee</label>
                        <p class="mt-1 text-sm text-gray-900">${this.formatEther(data.dispute.fee)} ETH</p>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Randomness Request ID</label>
                        <p class="mt-1 text-sm text-gray-900">#${data.dispute.randomnessRequestId}</p>
                    </div>
                </div>
                
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Voting Start</label>
                        <p class="mt-1 text-sm text-gray-900">${this.formatTimestamp(data.dispute.votingStartTime)}</p>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Voting End</label>
                        <p class="mt-1 text-sm text-gray-900">${this.formatTimestamp(data.dispute.votingEndTime)}</p>
                    </div>
                </div>
                
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Eligible Jurors</label>
                        <p class="mt-1 text-sm text-gray-900">${data.eligibleJurorCount}</p>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Can Assign Jurors</label>
                        <p class="mt-1 text-sm text-gray-900">
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                                data.canAssignJurors ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
                            }">
                                ${data.canAssignJurors ? 'Yes' : 'No'}
                            </span>
                        </p>
                    </div>
                </div>
                
                ${data.dispute.resolved ? `
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Majority Vote</label>
                        <p class="mt-1 text-sm text-gray-900">${this.getVoteLabel(data.dispute.majorityVote)}</p>
                    </div>
                ` : ''}
                
                <div class="flex justify-end space-x-3 pt-4">
                    <button onclick="dashboard.closeModal()" 
                            class="bg-gray-300 hover:bg-gray-400 text-gray-800 px-4 py-2 rounded-lg transition-colors">
                        Close
                    </button>
                    <button onclick="dashboard.fetchRequestDetails(${data.dispute.randomnessRequestId})" 
                            class="bg-purple-500 hover:bg-purple-600 text-white px-4 py-2 rounded-lg transition-colors">
                        View Randomness Request
                    </button>
                </div>
            </div>
        `;
        
        modal.classList.remove('hidden');
    }

    async fetchRequestDetails(requestId = null) {
        const input = document.getElementById('request-id-input');
        const requestIdToFetch = requestId || input.value;
        
        if (!requestIdToFetch) {
            alert('Please enter a request ID');
            return;
        }

        try {
            const response = await fetch(`/api/requests/${requestIdToFetch}`);
            const data = await response.json();
            
            if (response.ok) {
                this.showRequestDetails(data);
            } else {
                throw new Error(data.error || 'Failed to fetch request details');
            }
        } catch (error) {
            console.error('Failed to fetch request details:', error);
            this.showRequestError(error.message);
        }
    }

    showRequestDetails(data) {
        const container = document.getElementById('request-details');
        
        container.innerHTML = `
            <div class="space-y-4">
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Request ID</label>
                        <p class="mt-1 text-sm text-gray-900">#${data.requestId}</p>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Status</label>
                        <p class="mt-1 text-sm text-gray-900">
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                                data.fulfilled ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800'
                            }">
                                <span class="status-indicator ${data.fulfilled ? 'status-active' : 'status-pending'}"></span>
                                ${data.fulfilled ? 'Fulfilled' : 'Pending'}
                            </span>
                        </p>
                    </div>
                </div>
                
                ${data.fulfilled ? `
                    <div class="grid grid-cols-2 gap-4">
                        <div>
                            <label class="block text-sm font-medium text-gray-700">Random Value</label>
                            <p class="mt-1 text-sm text-gray-900 font-mono">${data.randomValue}</p>
                        </div>
                        <div>
                            <label class="block text-sm font-medium text-gray-700">Timestamp</label>
                            <p class="mt-1 text-sm text-gray-900">${this.formatTimestamp(data.timestamp)}</p>
                        </div>
                    </div>
                ` : `
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Requested At</label>
                        <p class="mt-1 text-sm text-gray-900">${this.formatTimestamp(data.timestamp)}</p>
                    </div>
                `}
                
                <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
                    <div class="flex">
                        <div class="flex-shrink-0">
                            <i class="fas fa-info-circle text-blue-400"></i>
                        </div>
                        <div class="ml-3">
                            <p class="text-sm text-blue-700">
                                This quantum randomness request is used for fair juror selection in the QJury dispute resolution system.
                            </p>
                        </div>
                    </div>
                </div>
            </div>
        `;
    }

    showRequestError(message) {
        const container = document.getElementById('request-details');
        container.innerHTML = `
            <div class="bg-red-50 border border-red-200 rounded-lg p-4">
                <div class="flex">
                    <div class="flex-shrink-0">
                        <i class="fas fa-exclamation-triangle text-red-400"></i>
                    </div>
                    <div class="ml-3">
                        <p class="text-sm text-red-700">
                            Error: ${message}
                        </p>
                    </div>
                </div>
            </div>
        `;
    }

    switchTab(tabName) {
        this.currentTab = tabName;
        
        // Update tab buttons
        document.querySelectorAll('.tab-btn').forEach(btn => {
            btn.classList.remove('border-blue-500', 'text-blue-600');
            btn.classList.add('border-transparent', 'text-gray-500');
        });
        
        const activeTab = document.getElementById(`${tabName}-tab`);
        activeTab.classList.remove('border-transparent', 'text-gray-500');
        activeTab.classList.add('border-blue-500', 'text-blue-600');
        
        // Show/hide content
        document.getElementById('disputes-content').classList.toggle('hidden', tabName !== 'disputes');
        document.getElementById('requests-content').classList.toggle('hidden', tabName !== 'requests');
        
        // Load data for the new tab
        if (tabName === 'requests') {
            document.getElementById('request-details').innerHTML = `
                <p class="text-gray-500 text-center">Enter a request ID to view details</p>
            `;
        }
    }

    filterDisputes(searchTerm) {
        const filtered = this.disputes.filter(dispute => 
            dispute.id.toString().includes(searchTerm) ||
            dispute.creator.toLowerCase().includes(searchTerm.toLowerCase())
        );
        
        this.renderFilteredDisputes(filtered);
    }

    renderFilteredDisputes(disputes) {
        const tbody = document.getElementById('disputes-tbody');
        
        if (disputes.length === 0) {
            tbody.innerHTML = `
                <tr>
                    <td colspan="5" class="px-6 py-4 text-center text-gray-500">
                        No disputes match your search
                    </td>
                </tr>
            `;
            return;
        }

        tbody.innerHTML = disputes.map(dispute => `
            <tr class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    #${dispute.id}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    ${this.shortenAddress(dispute.creator)}
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        dispute.resolved ? 'bg-gray-100 text-gray-800' : 'bg-green-100 text-green-800'
                    }">
                        <span class="status-indicator ${dispute.resolved ? 'status-resolved' : 'status-active'}"></span>
                        ${dispute.resolved ? 'Resolved' : 'Active'}
                    </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    ${this.formatTimestamp(dispute.votingEndTime)}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    <button onclick="dashboard.viewDisputeDetails(${dispute.id})" 
                            class="text-blue-600 hover:text-blue-900">
                        View Details
                    </button>
                </td>
            </tr>
        `).join('');
    }

    async refreshAll() {
        await this.checkConnection();
        await this.loadDisputes();
    }

    startAutoRefresh() {
        // Refresh data every 30 seconds
        setInterval(() => {
            this.refreshAll();
        }, 30000);
    }

    closeModal() {
        document.getElementById('dispute-modal').classList.add('hidden');
    }

    showLoading(type) {
        const tbody = document.getElementById('disputes-tbody');
        tbody.innerHTML = `
            <tr>
                <td colspan="5" class="px-6 py-4 text-center text-gray-500">
                    <div class="loading mx-auto"></div>
                    <p class="mt-2">Loading ${type}...</p>
                </td>
            </tr>
        `;
    }

    showError(type, message) {
        const tbody = document.getElementById('disputes-tbody');
        tbody.innerHTML = `
            <tr>
                <td colspan="5" class="px-6 py-4 text-center text-red-500">
                    <i class="fas fa-exclamation-triangle text-xl mb-2"></i>
                    <p>${message}</p>
                </td>
            </tr>
        `;
    }

    updateDisputeCount(count) {
        document.getElementById('total-disputes').textContent = count || '0';
    }

    // Utility functions
    shortenAddress(address) {
        return address ? `${address.slice(0, 6)}...${address.slice(-4)}` : 'Unknown';
    }

    formatTimestamp(timestamp) {
        if (!timestamp || timestamp === '0') return 'N/A';
        const date = new Date(Number(timestamp) * 1000);
        return date.toLocaleString();
    }

    formatEther(wei) {
        if (!wei) return '0';
        return (Number(wei) / 1e18).toFixed(6);
    }

    getVoteLabel(vote) {
        const votes = ['Support', 'Against', 'Abstain'];
        return votes[vote] || 'Unknown';
    }
}

// Initialize dashboard when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.dashboard = new QJuryDashboard();
});