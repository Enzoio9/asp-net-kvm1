// Main Application Logic
class OllamaWebApp {
    constructor() {
        this.api = window.ollamaAPI;
        this.activeJobs = new Map();
        this.init();
    }

    init() {
        this.bindEvents();
        this.connectWebSocket();
        this.loadGallery();
        console.log('🎬 Ollama Web initialized');
    }

    bindEvents() {
        // Create form submission
        const createForm = document.getElementById('createForm');
        if (createForm) {
            createForm.addEventListener('submit', (e) => this.handleCreateJob(e));
        }

        // Navigation smooth scroll
        document.querySelectorAll('a[href^="#"]').forEach(anchor => {
            anchor.addEventListener('click', (e) => {
                e.preventDefault();
                const target = document.querySelector(anchor.getAttribute('href'));
                if (target) {
                    target.scrollIntoView({ behavior: 'smooth', block: 'start' });
                }
            });
        });
    }

    connectWebSocket() {
        this.api.connectWebSocket(
            (data) => this.handleWebSocketMessage(data),
            (error) => console.error('WS Error:', error),
            () => console.log('WS Closed')
        );
    }

    handleWebSocketMessage(data) {
        if (data.type === 'jobs_update') {
            data.jobs.forEach(job => this.updateJobStatus(job));
        }
    }

    async handleCreateJob(e) {
        e.preventDefault();
        
        const form = e.target;
        const submitBtn = form.querySelector('button[type="submit"]');
        const btnText = submitBtn.querySelector('.btn-text');
        const btnLoader = submitBtn.querySelector('.btn-loader');

        try {
            // Show loading state
            submitBtn.disabled = true;
            btnText.style.display = 'none';
            btnLoader.style.display = 'inline';

            const formData = new FormData(form);
            const jobData = {
                prompt: formData.get('prompt'),
                duration: parseInt(formData.get('duration')),
                resolution: formData.get('resolution'),
                style: formData.get('style') || undefined
            };

            // Create job
            const job = await this.api.createJob(jobData);
            
            this.showNotification('Job created successfully!', 'success');
            
            // Add to active jobs
            this.activeJobs.set(job.id, job);
            this.renderActiveJobs();
            
            // Reset form
            form.reset();
            
        } catch (error) {
            this.showNotification(`Error: ${error.message}`, 'error');
        } finally {
            // Restore button state
            submitBtn.disabled = false;
            btnText.style.display = 'inline';
            btnLoader.style.display = 'none';
        }
    }

    updateJobStatus(jobUpdate) {
        const existingJob = this.activeJobs.get(jobUpdate.id);
        if (existingJob) {
            Object.assign(existingJob, jobUpdate);
            this.renderActiveJobs();
            
            // If completed, reload gallery
            if (jobUpdate.status === 'completed') {
                this.loadGallery();
                this.showNotification('Video generation complete!', 'success');
            }
        }
    }

    renderActiveJobs() {
        const container = document.getElementById('activeJobs');
        if (!container) return;

        if (this.activeJobs.size === 0) {
            container.innerHTML = '';
            return;
        }

        container.innerHTML = `
            <h3 style="margin-bottom: 15px; font-size: 20px;">Active Jobs</h3>
            ${Array.from(this.activeJobs.values()).map(job => this.renderJobCard(job)).join('')}
        `;
    }

    renderJobCard(job) {
        const statusClass = `status-${job.status.toLowerCase()}`;
        
        return `
            <div class="job-card" data-job-id="${job.id}">
                <div class="job-header">
                    <span class="job-id">${job.id}</span>
                    <span class="job-status ${statusClass}">${job.status}</span>
                </div>
                <p class="job-prompt">${this.escapeHtml(job.prompt)}</p>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: ${job.progress}%"></div>
                </div>
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <small style="color: var(--text-secondary);">Progress: ${job.progress}%</small>
                    ${job.status === 'pending' || job.status === 'processing' ? 
                        `<button onclick="app.cancelJob('${job.id}')" class="btn btn-small" style="background: var(--danger-color); color: white;">Cancel</button>` : 
                        ''
                    }
                </div>
            </div>
        `;
    }

    async cancelJob(jobId) {
        try {
            await this.api.cancelJob(jobId);
            this.showNotification('Job cancellation requested', 'warning');
        } catch (error) {
            this.showNotification(`Error: ${error.message}`, 'error');
        }
    }

    async loadGallery() {
        try {
            const jobs = await this.api.getJobs(null, 50, 0);
            this.renderGallery(jobs);
        } catch (error) {
            console.error('Failed to load gallery:', error);
        }
    }

    renderGallery(jobs) {
        const container = document.getElementById('videoGrid');
        if (!container) return;

        const completedJobs = jobs.filter(job => job.status === 'completed');

        if (completedJobs.length === 0) {
            container.innerHTML = '<p style="color: var(--text-secondary); text-align: center; padding: 40px;">No videos yet. Create your first video above!</p>';
            return;
        }

        container.innerHTML = completedJobs.map(job => `
            <div class="video-card">
                <div class="video-thumbnail">
                    ${job.video_url ? 
                        `<video src="${job.video_url}" controls style="width: 100%; height: 100%; object-fit: cover;"></video>` :
                        '🎬'
                    }
                </div>
                <div class="video-info">
                    <h4 class="video-title">${this.escapeHtml(job.prompt.substring(0, 50))}${job.prompt.length > 50 ? '...' : ''}</h4>
                    <p class="video-meta">
                        Created: ${new Date(job.created_at).toLocaleDateString()}<br>
                        Duration: ${job.progress}% complete
                    </p>
                    <div class="video-actions">
                        ${job.video_url ? 
                            `<a href="${job.video_url}" download class="btn btn-primary btn-small">Download</a>` : 
                            ''
                        }
                        <button onclick="app.deleteJob('${job.id}')" class="btn btn-small" style="background: var(--bg-card); border: 1px solid var(--border-color); color: var(--text-secondary);">Delete</button>
                    </div>
                </div>
            </div>
        `).join('');
    }

    async deleteJob(jobId) {
        if (!confirm('Are you sure you want to delete this job?')) return;

        try {
            await this.api.deleteJob(jobId);
            this.activeJobs.delete(jobId);
            this.renderActiveJobs();
            this.loadGallery();
            this.showNotification('Job deleted successfully', 'success');
        } catch (error) {
            this.showNotification(`Error: ${error.message}`, 'error');
        }
    }

    showNotification(message, type = 'info') {
        const container = document.getElementById('notifications');
        if (!container) return;

        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.textContent = message;

        container.appendChild(notification);

        // Auto-remove after 5 seconds
        setTimeout(() => {
            notification.style.animation = 'slideIn 0.3s ease reverse';
            setTimeout(() => notification.remove(), 300);
        }, 5000);
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Initialize app when DOM is ready
const app = new OllamaWebApp();
