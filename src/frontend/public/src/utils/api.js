// API Configuration
const API_BASE_URL = window.location.origin;
const API_VERSION = 'v1';

class OllamaAPI {
    constructor() {
        this.apiKey = localStorage.getItem('api_key') || '';
        this.ws = null;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 5;
    }

    // Generic request handler
    async request(endpoint, options = {}) {
        const url = `${API_BASE_URL}/api/${API_VERSION}/${endpoint}`;
        
        const headers = {
            'Content-Type': 'application/json',
            ...options.headers
        };

        if (this.apiKey) {
            headers['Authorization'] = `Bearer ${this.apiKey}`;
        }

        try {
            const response = await fetch(url, {
                ...options,
                headers
            });

            if (!response.ok) {
                const error = await response.json().catch(() => ({ detail: response.statusText }));
                throw new Error(error.detail || `HTTP ${response.status}`);
            }

            return await response.json();
        } catch (error) {
            console.error('API Request failed:', error);
            throw error;
        }
    }

    // Create a new video generation job with image upload
    async createJob(data) {
        const formData = new FormData();
        formData.append('prompt', data.prompt);
        formData.append('duration', data.duration || 5);
        formData.append('resolution', data.resolution || '720p');
        if (data.style) formData.append('style', data.style);
        
        // Add image if provided
        if (data.image) {
            formData.append('image', data.image);
        }

        return await this.request('jobs', {
            method: 'POST',
            body: formData,
            // Don't set Content-Type header, browser will set it with boundary
            headers: {}
        });
    }

    // Get all jobs
    async getJobs(status = null, limit = 50, offset = 0) {
        const params = new URLSearchParams({
            limit: limit.toString(),
            offset: offset.toString()
        });
        
        if (status) {
            params.append('status', status);
        }

        return await this.request(`jobs?${params.toString()}`);
    }

    // Get single job
    async getJob(jobId) {
        return await this.request(`jobs/${jobId}`);
    }

    // Cancel a job
    async cancelJob(jobId) {
        return await this.request(`jobs/${jobId}/cancel`, {
            method: 'POST'
        });
    }

    // Delete a job
    async deleteJob(jobId) {
        return await this.request(`jobs/${jobId}`, {
            method: 'DELETE'
        });
    }

    // Health check
    async health() {
        return await this.request('../health');
    }

    // WebSocket connection for real-time updates
    connectWebSocket(onMessage, onError, onClose) {
        const wsUrl = `ws://${window.location.host}/ws/jobs`;
        
        this.ws = new WebSocket(wsUrl);

        this.ws.onopen = () => {
            console.log('WebSocket connected');
            this.reconnectAttempts = 0;
        };

        this.ws.onmessage = (event) => {
            const data = JSON.parse(event.data);
            onMessage(data);
        };

        this.ws.onerror = (error) => {
            console.error('WebSocket error:', error);
            if (onError) onError(error);
        };

        this.ws.onclose = () => {
            console.log('WebSocket closed');
            if (onClose) onClose();
            
            // Attempt to reconnect
            if (this.reconnectAttempts < this.maxReconnectAttempts) {
                this.reconnectAttempts++;
                console.log(`Reconnecting in ${this.reconnectAttempts * 2}s...`);
                setTimeout(() => {
                    this.connectWebSocket(onMessage, onError, onClose);
                }, this.reconnectAttempts * 2000);
            }
        };
    }

    disconnectWebSocket() {
        if (this.ws) {
            this.ws.close();
            this.ws = null;
        }
    }
}

// Export singleton instance
window.ollamaAPI = new OllamaAPI();
