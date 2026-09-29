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

// Token Counter and Rabbit RAM storage layer
(function() {
    const STORAGE_KEY = 'leo3c-rabbit-ram-tokens';

    function readTokens() {
        try {
            const raw = localStorage.getItem(STORAGE_KEY);
            const parsed = raw ? JSON.parse(raw) : [];
            return Array.isArray(parsed) ? parsed : [];
        } catch (error) {
            console.warn('Token storage unavailable, using memory fallback:', error);
            return [];
        }
    }

    function writeTokens(tokens) {
        try {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(tokens));
        } catch (error) {
            console.warn('Token storage write failed:', error);
        }
    }

    function generateTokenId() {
        if (typeof crypto !== 'undefined' && crypto.randomUUID) {
            return crypto.randomUUID();
        }
        return `token-${Date.now()}-${Math.random().toString(16).slice(2, 10)}`;
    }

    function sanitizeRecord(record) {
        return {
            tokenId: record.tokenId || generateTokenId(),
            topic: record.topic || 'general',
            status: record.status || 'created',
            source: record.source || 'system',
            ipAddress: record.ipAddress || 'unknown',
            createdAt: record.createdAt || new Date().toISOString(),
            updatedAt: record.updatedAt || new Date().toISOString(),
            count: Number.isFinite(record.count) ? record.count : 1,
            costIncurred: Number.isFinite(record.costIncurred) ? record.costIncurred : 0,
            royalty: Number.isFinite(record.royalty) ? record.royalty : 0,
            metadata: record.metadata || {}
        };
    }

    const TokenCounter = {
        createToken(details = {}) {
            const tokens = readTokens();
            const record = sanitizeRecord({
                ...details,
                tokenId: details.tokenId || generateTokenId(),
                createdAt: details.createdAt || new Date().toISOString(),
                updatedAt: details.updatedAt || new Date().toISOString(),
                count: details.count || 1,
                metadata: details.metadata || {}
            });

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

        updateToken(tokenId, changes = {}) {
            const tokens = readTokens();
            const index = tokens.findIndex(token => token.tokenId === tokenId);
            if (index === -1) {
                return null;
            }

            const updated = sanitizeRecord({
                ...tokens[index],
                ...changes,
                tokenId,
                updatedAt: new Date().toISOString()
            });

            tokens[index] = updated;
            writeTokens(tokens);
            this.syncToRabbitRAM();
            return updated;
        },

        prepareCloudPayload() {
            const tokens = readTokens();
            return {
                source: 'rabbit-ram',
                generatedAt: new Date().toISOString(),
                totalTokens: tokens.length,
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
                    metadata: token.metadata
                }))
            };
        },

        syncToRabbitRAM() {
            const payload = this.prepareCloudPayload();
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

            counterEl.textContent = String(this.countTokens());
            counterEl.setAttribute('data-total-tokens', String(this.countTokens()));
        }
    };

    if (typeof window !== 'undefined') {
        window.TokenCounter = TokenCounter;
        window.tokenCounter = TokenCounter;
    }

    if (typeof module !== 'undefined' && module.exports) {
        module.exports = TokenCounter;
    }

    document.addEventListener('DOMContentLoaded', () => {
        TokenCounter.hydrateCounterUI();
    });
})();

// Log page info
console.log('LEO 3C AI Success Case Study');
console.log('Timestamp: 27 Sep 2026 BKK');
console.log('Personal IP Protection - MIT License');
console.log('Architecture: IA&IB');
console.log('Token Counter Ready:', typeof window !== 'undefined' ? window.TokenCounter?.countTokens?.() : 'browser-only');
