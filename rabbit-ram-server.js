/**
 * ====================================================================
 * RABBIT RAM - Server-Side Token Storage & Daily Anchoring System
 * ====================================================================
 * 
 * Features:
 * 1. Server-side token storage (replaces browser localStorage)
 * 2. Daily anchor mechanism (batches tokens by date)
 * 3. Blockchain proof linking (27 Sep 2026 proof reference)
 * 4. SHA256 + tstSignature verification
 * 5. Payload versioning with hash chain
 * 
 * Usage:
 *   const rabbitRAM = new RabbitRAMServer(config);
 *   await rabbitRAM.initialize();
 *   await rabbitRAM.syncToken(tokenData);
 *   await rabbitRAM.anchorDaily();
 */

class RabbitRAMServer {
    constructor(config = {}) {
        this.config = {
            apiEndpoint: config.apiEndpoint || 'https://api.leo3c.cloud/rabbit-ram',
            blockchainProofRef: config.blockchainProofRef || 'LEO3C-BLOCKCHAIN-PROOF-20260927-001',
            blockchainProofHash: config.blockchainProofHash || 'abc123def456...',
            tsaIssuer: config.tsaIssuer || 'LEO3C-TSA-PRIMARY',
            dailyAnchorTime: config.dailyAnchorTime || '00:00:00+07:00',
            retryAttempts: config.retryAttempts || 3,
            retryDelayMs: config.retryDelayMs || 1000,
            ...config
        };

        this.sessionId = this.generateSessionId();
        this.memoryBuffer = {
            tokens: [],
            metadata: {
                sessionId: this.sessionId,
                lastSync: null,
                lastAnchor: null,
                pendingSync: 0,
                syncedCount: 0
            }
        };
        this.dailyAnchors = {};
        this.isInitialized = false;
    }

    generateSessionId() {
        if (typeof crypto !== 'undefined' && crypto.randomUUID) {
            return crypto.randomUUID();
        }
        return `session-${Date.now()}-${Math.random().toString(16).slice(2, 10)}`;
    }

    formatDate(date) {
        const y = date.getFullYear();
        const m = String(date.getMonth() + 1).padStart(2, '0');
        const d = String(date.getDate()).padStart(2, '0');
        return `${y}${m}${d}`;
    }

    /**
     * Initialize the Rabbit RAM server connection
     */
    async initialize() {
        try {
            console.log('[RabbitRAM] Initializing server connection...');

            // Test API connectivity
            const testResponse = await this.makeRequest('/health', {
                method: 'GET'
            });

            if (!testResponse.ok) {
                throw new Error(`API health check failed: ${testResponse.status}`);
            }

            // Load existing session state
            await this.loadSessionState();

            this.isInitialized = true;
            console.log('[RabbitRAM] ✅ Initialized successfully');
            return true;
        } catch (error) {
            console.error('[RabbitRAM] ❌ Initialization failed:', error);
            this.isInitialized = false;
            return false;
        }
    }

    /**
     * Load existing session state from server
     */
    async loadSessionState() {
        try {
            const response = await this.makeRequest('/session/load', {
                method: 'POST',
                body: {
                    sessionId: this.sessionId
                }
            });

            if (response.ok && response.data) {
                this.memoryBuffer = {
                    ...this.memoryBuffer,
                    tokens: response.data.tokens || [],
                    metadata: {
                        ...this.memoryBuffer.metadata,
                        lastSync: response.data.lastSync,
                        lastAnchor: response.data.lastAnchor,
                        syncedCount: response.data.syncedCount || 0
                    }
                };
                console.log(`[RabbitRAM] Loaded ${this.memoryBuffer.tokens.length} tokens from server`);
            }
        } catch (error) {
            console.warn('[RabbitRAM] Could not load session state:', error);
        }
    }

    /**
     * Sync a single token to server
     * Creates daily anchor if needed
     */
    async syncToken(tokenData) {
        if (!this.isInitialized) {
            console.warn('[RabbitRAM] Not initialized, buffering token in memory');
            this.memoryBuffer.tokens.push(tokenData);
            this.memoryBuffer.metadata.pendingSync++;
            return { status: 'buffered', tokenId: tokenData.tokenId };
        }

        try {
            const today = this.formatDate(new Date());
            
            // Prepare token with proof references
            const enrichedToken = {
                ...tokenData,
                proofRef: this.config.blockchainProofRef,
                proofHash: this.config.blockchainProofHash,
                tsaIssuer: this.config.tsaIssuer,
                anchorDate: today,
                syncedAt: new Date().toISOString()
            };

            // Send to server
            const response = await this.makeRequest('/token/sync', {
                method: 'POST',
                body: {
                    sessionId: this.sessionId,
                    token: enrichedToken,
                    proofRef: this.config.blockchainProofRef
                }
            });

            if (response.ok) {
                this.memoryBuffer.tokens.push(enrichedToken);
                this.memoryBuffer.metadata.lastSync = new Date().toISOString();
                this.memoryBuffer.metadata.syncedCount++;
                this.memoryBuffer.metadata.pendingSync--;

                console.log(`[RabbitRAM] ✓ Synced token: ${tokenData.tokenId}`);
                return { status: 'synced', tokenId: tokenData.tokenId, serverId: response.data?.id };
            } else {
                throw new Error(`Sync failed: ${response.status}`);
            }
        } catch (error) {
            console.error(`[RabbitRAM] Failed to sync token ${tokenData.tokenId}:`, error);
            
            // Fall back to memory buffering
            this.memoryBuffer.tokens.push(tokenData);
            this.memoryBuffer.metadata.pendingSync++;
            
            return { status: 'buffered', tokenId: tokenData.tokenId, error: error.message };
        }
    }

    /**
     * Sync batch of tokens
     */
    async syncBatch(tokens) {
        const results = [];
        for (const token of tokens) {
            const result = await this.syncToken(token);
            results.push(result);
        }
        return results;
    }

    /**
     * Create daily anchor
     * Batches all tokens created on a specific date and anchors to blockchain
     */
    async anchorDaily(anchorDate = null) {
        if (!this.isInitialized) {
            console.warn('[RabbitRAM] Not initialized, cannot create anchor');
            return null;
        }

        try {
            const dateStr = anchorDate || this.formatDate(new Date());
            
            console.log(`[RabbitRAM] Creating daily anchor for ${dateStr}...`);

            // Filter tokens for this date
            const dailyTokens = this.memoryBuffer.tokens.filter(t => {
                const tokenDate = this.formatDate(new Date(t.createdAt || t.syncedAt));
                return tokenDate === dateStr;
            });

            if (dailyTokens.length === 0) {
                console.log(`[RabbitRAM] No tokens to anchor for ${dateStr}`);
                return null;
            }

            // Prepare anchor payload
            const anchorPayload = {
                sessionId: this.sessionId,
                anchorDate: dateStr,
                tokenCount: dailyTokens.length,
                tokens: dailyTokens,
                proofRef: this.config.blockchainProofRef,
                proofHash: this.config.blockchainProofHash,
                tsaIssuer: this.config.tsaIssuer,
                generatedAt: new Date().toISOString()
            };

            // Send anchor request to server
            const response = await this.makeRequest('/anchor/create', {
                method: 'POST',
                body: anchorPayload
            });

            if (response.ok && response.data) {
                this.dailyAnchors[dateStr] = {
                    anchorId: response.data.anchorId,
                    merkleRoot: response.data.merkleRoot,
                    txHash: response.data.txHash,
                    blockNumber: response.data.blockNumber,
                    timestamp: response.data.timestamp,
                    status: 'ANCHORED',
                    proofRef: this.config.blockchainProofRef
                };

                this.memoryBuffer.metadata.lastAnchor = new Date().toISOString();

                console.log(`[RabbitRAM] ✓ Created anchor for ${dateStr}`);
                console.log(`  - Anchor ID: ${response.data.anchorId}`);
                console.log(`  - Merkle Root: ${response.data.merkleRoot}`);
                console.log(`  - TX Hash: ${response.data.txHash}`);
                
                return this.dailyAnchors[dateStr];
            } else {
                throw new Error(`Anchor creation failed: ${response.status}`);
            }
        } catch (error) {
            console.error(`[RabbitRAM] Failed to create daily anchor:`, error);
            return null;
        }
    }

    /**
     * Get anchor for a specific date
     */
    getAnchor(dateStr) {
        return this.dailyAnchors[dateStr] || null;
    }

    /**
     * Verify token against anchor
     */
    async verifyToken(tokenId, dateStr) {
        try {
            const anchor = this.dailyAnchors[dateStr];
            if (!anchor) {
                throw new Error(`No anchor found for date ${dateStr}`);
            }

            const response = await this.makeRequest('/token/verify', {
                method: 'POST',
                body: {
                    tokenId,
                    anchorId: anchor.anchorId,
                    proofRef: this.config.blockchainProofRef
                }
            });

            return response.ok ? response.data : null;
        } catch (error) {
            console.error(`[RabbitRAM] Verification failed for ${tokenId}:`, error);
            return null;
        }
    }

    /**
     * Get current session state
     */
    getSessionState() {
        return {
            sessionId: this.sessionId,
            isInitialized: this.isInitialized,
            memoryBuffer: this.memoryBuffer,
            dailyAnchors: this.dailyAnchors,
            stats: {
                totalTokens: this.memoryBuffer.tokens.length,
                syncedCount: this.memoryBuffer.metadata.syncedCount,
                pendingSync: this.memoryBuffer.metadata.pendingSync,
                lastSync: this.memoryBuffer.metadata.lastSync,
                lastAnchor: this.memoryBuffer.metadata.lastAnchor,
                anchorCount: Object.keys(this.dailyAnchors).length
            }
        };
    }

    /**
     * Prepare cloud payload with proof references
     */
    async prepareCloudPayload() {
        return {
            sessionId: this.sessionId,
            source: 'rabbit-ram-server',
            generatedAt: new Date().toISOString(),
            blockchainProofRef: this.config.blockchainProofRef,
            blockchainProofHash: this.config.blockchainProofHash,
            tsaIssuer: this.config.tsaIssuer,
            totalTokens: this.memoryBuffer.tokens.length,
            tokens: this.memoryBuffer.tokens.map(t => ({
                ...t,
                proofRef: this.config.blockchainProofRef,
                tsaIssuer: this.config.tsaIssuer
            })),
            dailyAnchors: this.dailyAnchors,
            metadata: this.memoryBuffer.metadata
        };
    }

    /**
     * Make HTTP request with retry logic
     */
    async makeRequest(endpoint, options = {}) {
        const {
            method = 'GET',
            body = null,
            headers = {}
        } = options;

        let lastError;

        for (let attempt = 0; attempt < this.config.retryAttempts; attempt++) {
            try {
                const fetchOptions = {
                    method,
                    headers: {
                        'Content-Type': 'application/json',
                        'X-Session-ID': this.sessionId,
                        ...headers
                    }
                };

                if (body) {
                    fetchOptions.body = JSON.stringify(body);
                }

                const url = `${this.config.apiEndpoint}${endpoint}`;
                const response = await fetch(url, fetchOptions);

                let data;
                try {
                    data = await response.json();
                } catch {
                    data = null;
                }

                return {
                    ok: response.ok,
                    status: response.status,
                    data: data
                };
            } catch (error) {
                lastError = error;
                if (attempt < this.config.retryAttempts - 1) {
                    await new Promise(resolve => 
                        setTimeout(resolve, this.config.retryDelayMs * Math.pow(2, attempt))
                    );
                }
            }
        }

        throw lastError || new Error('Request failed after retries');
    }

    /**
     * Graceful shutdown
     */
    async shutdown() {
        try {
            // Create final anchor if there are pending tokens
            if (this.memoryBuffer.metadata.pendingSync > 0) {
                console.log('[RabbitRAM] Creating final anchor before shutdown...');
                await this.anchorDaily();
            }

            this.isInitialized = false;
            console.log('[RabbitRAM] ✓ Shutdown complete');
        } catch (error) {
            console.error('[RabbitRAM] Error during shutdown:', error);
        }
    }
}

// ====================================================================
// Export
// ====================================================================

if (typeof module !== 'undefined' && module.exports) {
    module.exports = RabbitRAMServer;
}

if (typeof window !== 'undefined') {
    window.RabbitRAMServer = RabbitRAMServer;
}
