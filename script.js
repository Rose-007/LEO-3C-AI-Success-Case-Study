// Smooth scroll to section
function scrollToSection(sectionId) {
    const section = document.getElementById(sectionId);
    if (section) {
        section.scrollIntoView({
            behavior: 'smooth',
            block: 'start'
        });
    }
}

// Handle form submission
function handleSubmit(event) {
    event.preventDefault();
    
    const name = document.getElementById('name').value;
    const email = document.getElementById('email').value;
    const message = document.getElementById('message').value;
    
    // Validate form
    if (!name || !email || !message) {
        showAlert('โปรดกรอกข้อมูลให้ครบถ้วน', 'error');
        return;
    }
    
    // Simulate form submission
    console.log('Form submitted:', {
        name: name,
        email: email,
        message: message
    });
    
    // Show success message
    showAlert('ส่งข้อความสำเร็จแล้ว! ขอบคุณที่ติดต่อเรา', 'success');
    
    // Reset form
    document.querySelector('.contact-form').reset();
}

// Show alert message
function showAlert(message, type) {
    const alertClass = type === 'success' ? 'alert-success' : 'alert-error';
    const alertDiv = document.createElement('div');
    alertDiv.className = `alert ${alertClass}`;
    alertDiv.textContent = message;
    
    // Add style
    alertDiv.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 15px 20px;
        border-radius: 5px;
        color: white;
        font-weight: 500;
        z-index: 9999;
        animation: slideIn 0.3s ease;
        ${type === 'success' ? 'background-color: #2ecc71;' : 'background-color: #e74c3c;'}
    `;
    
    document.body.appendChild(alertDiv);
    
    // Remove after 3 seconds
    setTimeout(() => {
        alertDiv.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => alertDiv.remove(), 300);
    }, 3000);
}

// Add animation styles
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from {
            transform: translateX(400px);
            opacity: 0;
        }
        to {
            transform: translateX(0);
            opacity: 1;
        }
    }
    
    @keyframes slideOut {
        from {
            transform: translateX(0);
            opacity: 1;
        }
        to {
            transform: translateX(400px);
            opacity: 0;
        }
    }
`;
document.head.appendChild(style);

// Active nav link on scroll
document.addEventListener('DOMContentLoaded', function() {
    const sections = document.querySelectorAll('section[id]');
    const navLinks = document.querySelectorAll('.nav-menu a');
    
    window.addEventListener('scroll', () => {
        let current = '';
        
        sections.forEach(section => {
            const sectionTop = section.offsetTop;
            const sectionHeight = section.clientHeight;
            
            if (scrollY >= sectionTop - 200) {
                current = section.getAttribute('id');
            }
        });
        
        navLinks.forEach(link => {
            link.classList.remove('active');
            if (link.getAttribute('href').slice(1) === current) {
                link.classList.add('active');
            }
        });
    });
});

// Add active style for nav links
const navStyle = document.createElement('style');
navStyle.textContent = `
    .nav-menu a.active {
        color: var(--primary-color);
        border-bottom: 2px solid var(--primary-color);
        padding-bottom: 5px;
    }
`;
document.head.appendChild(navStyle);

// ====================================================================
// SHA256 Hash Function (for token integrity)
// ====================================================================
const SHA256 = (() => {
    const sha256 = async (message) => {
        // Convert string to ArrayBuffer
        const encoder = new TextEncoder();
        const data = encoder.encode(message);
        
        // Use SubtleCrypto for SHA-256 (available in modern browsers)
        if (typeof window !== 'undefined' && window.crypto && window.crypto.subtle) {
            try {
                const hashBuffer = await window.crypto.subtle.digest('SHA-256', data);
                // Convert ArrayBuffer to hex string
                const hashArray = Array.from(new Uint8Array(hashBuffer));
                const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
                return hashHex;
            } catch (error) {
                console.warn('SHA-256 via SubtleCrypto failed:', error);
                return sha256Fallback(message);
            }
        }
        
        return sha256Fallback(message);
    };

    // Fallback SHA-256 implementation (simple polyfill)
    const sha256Fallback = (message) => {
        const K = [
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
            0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
            0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
            0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
            0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
            0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
            0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
            0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
        ];

        let h0 = 0x6a09e667, h1 = 0xbb67ae85, h2 = 0x3c6ef372, h3 = 0xa54ff53a,
            h4 = 0x510e527f, h5 = 0x9b05688c, h6 = 0x1f83d9ab, h7 = 0x5be0cd19;

        const msg = new Uint8Array(message.length);
        for (let i = 0; i < message.length; i++) msg[i] = message.charCodeAt(i) & 0xff;

        const msgLen = message.length * 8;
        const msgPadded = new Uint8Array(Math.ceil((msgLen + 65) / 512) * 64);
        msgPadded.set(msg);
        msgPadded[msg.length] = 0x80;

        const view = new DataView(msgPadded.buffer);
        view.setBigInt64(msgPadded.length - 8, BigInt(msgLen), false);

        for (let offset = 0; offset < msgPadded.length; offset += 64) {
            const w = new Uint32Array(64);
            for (let i = 0; i < 16; i++) {
                w[i] = view.getUint32(offset + i * 4, false);
            }

            for (let i = 16; i < 64; i++) {
                const s0 = rightRotate(w[i - 15], 7) ^ rightRotate(w[i - 15], 18) ^ (w[i - 15] >>> 3);
                const s1 = rightRotate(w[i - 2], 17) ^ rightRotate(w[i - 2], 19) ^ (w[i - 2] >>> 10);
                w[i] = (w[i - 16] + s0 + w[i - 7] + s1) >>> 0;
            }

            let a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;

            for (let i = 0; i < 64; i++) {
                const S1 = rightRotate(e, 6) ^ rightRotate(e, 11) ^ rightRotate(e, 25);
                const ch = (e & f) ^ (~e & g);
                const temp1 = (h + S1 + ch + K[i] + w[i]) >>> 0;
                const S0 = rightRotate(a, 2) ^ rightRotate(a, 13) ^ rightRotate(a, 22);
                const maj = (a & b) ^ (a & c) ^ (b & c);
                const temp2 = (S0 + maj) >>> 0;

                h = g;
                g = f;
                f = e;
                e = (d + temp1) >>> 0;
                d = c;
                c = b;
                b = a;
                a = (temp1 + temp2) >>> 0;
            }

            h0 = (h0 + a) >>> 0;
            h1 = (h1 + b) >>> 0;
            h2 = (h2 + c) >>> 0;
            h3 = (h3 + d) >>> 0;
            h4 = (h4 + e) >>> 0;
            h5 = (h5 + f) >>> 0;
            h6 = (h6 + g) >>> 0;
            h7 = (h7 + h) >>> 0;
        }

        const hex = (x) => x.toString(16).padStart(8, '0');
        return hex(h0) + hex(h1) + hex(h2) + hex(h3) + hex(h4) + hex(h5) + hex(h6) + hex(h7);
    };

    const rightRotate = (x, n) => (x >>> n) | (x << (32 - n));

    return { hash: sha256, fallback: sha256Fallback };
})();

// ====================================================================
// Token ID Generator (BTM-LEO3C-YYYYMMDD-XXXX format)
// ====================================================================
const TokenIDGenerator = (() => {
    let dailyCounter = {};

    const formatDate = (date) => {
        const y = date.getFullYear();
        const m = String(date.getMonth() + 1).padStart(2, '0');
        const d = String(date.getDate()).padStart(2, '0');
        return `${y}${m}${d}`;
    };

    const generateSerialNumber = (dateStr) => {
        if (!dailyCounter[dateStr]) {
            dailyCounter[dateStr] = 0;
        }
        dailyCounter[dateStr]++;
        return String(dailyCounter[dateStr]).padStart(4, '0');
    };

    return {
        generate: () => {
            const now = new Date();
            const dateStr = formatDate(now);
            const serial = generateSerialNumber(dateStr);
            return `BTM-LEO3C-${dateStr}-${serial}`;
        },

        parse: (tokenId) => {
            const pattern = /^BTM-LEO3C-(\d{8})-(\d{4})$/;
            const match = tokenId.match(pattern);
            if (!match) return null;
            
            const dateStr = match[1];
            const serial = match[2];
            return {
                prefix: 'BTM-LEO3C',
                date: dateStr,
                serial: serial,
                year: parseInt(dateStr.substring(0, 4)),
                month: parseInt(dateStr.substring(4, 6)),
                day: parseInt(dateStr.substring(6, 8))
            };
        }
    };
})();

// ====================================================================
// Token Counter and Rabbit RAM storage layer with SHA256 + Valuation
// ====================================================================
(function() {
    const STORAGE_KEY = 'leo3c-rabbit-ram-tokens';
    const SIGNATURE_KEY = 'leo3c-rabbit-ram-sig';
    let memoryTokens = [];

    // Valuation status constants
    const VALUATION_STATUS = {
        PROOF_ONLY: 'PROOF_ONLY',      // Token created, proof only, no value yet
        ACTIVATED: 'ACTIVATED',        // Token activated for valuation
        VALUED: 'VALUED'               // Real value assigned
    };

    function readTokens() {
        try {
            const raw = localStorage.getItem(STORAGE_KEY);
            const parsed = raw ? JSON.parse(raw) : [];
            return Array.isArray(parsed) ? parsed : memoryTokens;
        } catch (error) {
            console.warn('Token storage unavailable, using memory fallback:', error);
            return memoryTokens;
        }
    }

    function writeTokens(tokens) {
        memoryTokens = [...tokens];

        try {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(tokens));
        } catch (error) {
            console.warn('Token storage write failed:', error);
        }
    }

    // Generate timestamp signature
    function generateTimestampSignature() {
        const timestamp = Date.now();
        const nonce = Math.random().toString(16).slice(2, 10);
        return {
            timestamp,
            nonce,
            signature: `tstSig_${timestamp}_${nonce}`
        };
    }

    async function computeTokenHash(token) {
        const tokenString = JSON.stringify({
            tokenId: token.tokenId,
            topic: token.topic,
            status: token.status,
            count: token.count,
            costIncurred: token.costIncurred,
            royalty: token.royalty,
            realValue: token.realValue,
            btmValue: token.btmValue,
            valuationStatus: token.valuationStatus,
            createdAt: token.createdAt
        });

        return await SHA256.hash(tokenString);
    }

    async function generatePayloadSignature(payload) {
        const payloadString = JSON.stringify(payload);
        return await SHA256.hash(payloadString);
    }

    function sanitizeRecord(record) {
        const tsSig = generateTimestampSignature();
        return {
            tokenId: record.tokenId || TokenIDGenerator.generate(),
            topic: record.topic || 'general',
            status: record.status || 'Order',
            source: record.source || 'system',
            ipAddress: record.ipAddress || 'unknown',
            createdAt: record.createdAt || new Date().toISOString(),
            updatedAt: record.updatedAt || new Date().toISOString(),
            count: Number.isFinite(record.count) ? record.count : 1,
            costIncurred: Number.isFinite(record.costIncurred) ? record.costIncurred : 0,
            royalty: Number.isFinite(record.royalty) ? record.royalty : 0,
            // NEW: Valuation fields
            realValue: Number.isFinite(record.realValue) ? record.realValue : 0,
            btmValue: Number.isFinite(record.btmValue) ? record.btmValue : 0,
            valuationStatus: record.valuationStatus || VALUATION_STATUS.PROOF_ONLY,
            // Signature fields
            metadata: record.metadata || {},
            tstSignature: record.tstSignature || tsSig.signature,
            tstTimestamp: record.tstTimestamp || tsSig.timestamp
        };
    }

    const TokenCounter = {
        // Constants
        VALUATION_STATUS,

        async createToken(details = {}) {
            const tokens = readTokens();
            const record = sanitizeRecord({
                ...details,
                tokenId: details.tokenId || TokenIDGenerator.generate(),
                createdAt: details.createdAt || new Date().toISOString(),
                updatedAt: details.updatedAt || new Date().toISOString(),
                count: Number.isFinite(details.count) ? details.count : 1,
                realValue: Number.isFinite(details.realValue) ? details.realValue : 0,
                btmValue: Number.isFinite(details.btmValue) ? details.btmValue : 0,
                valuationStatus: details.valuationStatus || VALUATION_STATUS.PROOF_ONLY,
                metadata: details.metadata || {}
            });

            // Compute SHA256 hash for the token
            record.sha256 = await computeTokenHash(record);

            tokens.push(record);
            writeTokens(tokens);
            this.syncToRabbitRAM();
            return record;
        },

        getTokenData() {
            return readTokens();
        },

        countTokens() {
            return readTokens().length;
        },

        getTokenById(tokenId) {
            return readTokens().find(token => token.tokenId === tokenId) || null;
        },

        async updateToken(tokenId, changes = {}) {
            const tokens = readTokens();
            const index = tokens.findIndex(token => token.tokenId === tokenId);
            if (index === -1) {
                return null;
            }

            const tsSig = generateTimestampSignature();
            const updated = sanitizeRecord({
                ...tokens[index],
                ...changes,
                tokenId,
                updatedAt: new Date().toISOString(),
                tstSignature: tsSig.signature,
                tstTimestamp: tsSig.timestamp
            });

            // Recompute SHA256 hash after update
            updated.sha256 = await computeTokenHash(updated);

            tokens[index] = updated;
            writeTokens(tokens);
            this.syncToRabbitRAM();
            return updated;
        },

        // NEW: Activate token for valuation
        async activateToken(tokenId) {
            return this.updateToken(tokenId, {
                valuationStatus: VALUATION_STATUS.ACTIVATED
            });
        },

        // NEW: Set real value and update status to VALUED
        async setRealValue(tokenId, realValue, btmValue = 0) {
            if (!Number.isFinite(realValue) || realValue < 0) {
                console.error('Invalid realValue:', realValue);
                return null;
            }

            return this.updateToken(tokenId, {
                realValue: realValue,
                btmValue: Number.isFinite(btmValue) ? btmValue : 0,
                valuationStatus: VALUATION_STATUS.VALUED
            });
        },

        // NEW: Get tokens by valuation status
        getTokensByValuationStatus(status) {
            const validStatus = Object.values(VALUATION_STATUS);
            if (!validStatus.includes(status)) {
                console.warn(`Invalid valuation status: ${status}`);
                return [];
            }
            return readTokens().filter(token => token.valuationStatus === status);
        },

        // NEW: Get total value across tokens
        getTotalValue(valuationStatus = null) {
            let tokens = readTokens();
            if (valuationStatus) {
                tokens = tokens.filter(t => t.valuationStatus === valuationStatus);
            }
            return tokens.reduce((sum, token) => sum + token.realValue, 0);
        },

        // NEW: Get total BTM value
        getTotalBTMValue(valuationStatus = null) {
            let tokens = readTokens();
            if (valuationStatus) {
                tokens = tokens.filter(t => t.valuationStatus === valuationStatus);
            }
            return tokens.reduce((sum, token) => sum + token.btmValue, 0);
        },

        async verifyTokenIntegrity(token) {
            if (!token.sha256) {
                console.warn('Token missing sha256 hash');
                return false;
            }

            const computedHash = await computeTokenHash(token);
            const isValid = computedHash === token.sha256;

            if (!isValid) {
                console.error(`Token integrity check failed for ${token.tokenId}`);
            }

            return isValid;
        },

        async prepareCloudPayload() {
            const tokens = readTokens();
            const payload = {
                source: 'rabbit-ram',
                generatedAt: new Date().toISOString(),
                totalTokens: tokens.length,
                valuationSummary: {
                    totalRealValue: this.getTotalValue(),
                    totalBTMValue: this.getTotalBTMValue(),
                    byStatus: {
                        [VALUATION_STATUS.PROOF_ONLY]: this.getTotalValue(VALUATION_STATUS.PROOF_ONLY),
                        [VALUATION_STATUS.ACTIVATED]: this.getTotalValue(VALUATION_STATUS.ACTIVATED),
                        [VALUATION_STATUS.VALUED]: this.getTotalValue(VALUATION_STATUS.VALUED)
                    }
                },
                tokens: tokens.map(token => ({
                    tokenId: token.tokenId,
                    topic: token.topic,
                    status: token.status,
                    source: token.source,
                    ipAddress: token.ipAddress,
                    createdAt: token.createdAt,
                    updatedAt: token.updatedAt,
                    count: token.count,
                    costIncurred: token.costIncurred,
                    royalty: token.royalty,
                    realValue: token.realValue,
                    btmValue: token.btmValue,
                    valuationStatus: token.valuationStatus,
                    metadata: token.metadata,
                    sha256: token.sha256 || 'pending',
                    tstSignature: token.tstSignature,
                    tstTimestamp: token.tstTimestamp
                }))
            };

            // Generate signature for entire payload
            payload.payloadSignature = await generatePayloadSignature(payload);

            return payload;
        },

        async syncToRabbitRAM() {
            const payload = await this.prepareCloudPayload();
            if (typeof window !== 'undefined') {
                window.__LEO3C_RABBIT_RAM__ = payload;
            }
            return payload;
        },

        hydrateCounterUI() {
            if (typeof document === 'undefined') {
                return;
            }

            const counterEl = document.getElementById('token-counter');
            if (!counterEl) {
                return;
            }

            const total = this.countTokens();
            counterEl.textContent = String(total);
            counterEl.setAttribute('data-total-tokens', String(total));
        }
    };

    if (typeof window !== 'undefined') {
        window.TokenCounter = TokenCounter;
        window.tokenCounter = TokenCounter;
        window.TokenIDGenerator = TokenIDGenerator;
    }

    if (typeof module !== 'undefined' && module.exports) {
        module.exports = TokenCounter;
    }

    if (typeof document !== 'undefined') {
        document.addEventListener('DOMContentLoaded', () => {
            TokenCounter.hydrateCounterUI();
        });
    }
})();

// Log page info
console.log('LEO 3C AI Success Case Study');
console.log('Timestamp: 27 Sep 2026 BKK');
console.log('Personal IP Protection - MIT License');
console.log('Architecture: IA&IB');
console.log('Token Counter Ready:', typeof window !== 'undefined' ? window.TokenCounter?.countTokens?.() : 'browser-only');
console.log('SHA256 + Timestamp Signature: ENABLED');
console.log('Token Valuation System: ENABLED (PROOF_ONLY | ACTIVATED | VALUED)');
console.log('Token ID Format: BTM-LEO3C-YYYYMMDD-XXXX');
