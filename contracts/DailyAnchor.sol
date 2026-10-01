// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * ====================================================================
 * DailyAnchor.sol — AI-Success Daily Merkle Root Anchor
 * ====================================================================
 * 
 * Owner: พุฒฬส ตระกูลทอง | AI-Success Foundation
 * 
 * Purpose: 
 *   - Daily batch of BTM tokens → Merkle root
 *   - Anchor root to public chain (Polygon/BNB) at 00:00 UTC
 *   - Immutable proof for all 3 revenue streams:
 *     1. GPT Training Data discovery
 *     2. AI-Success Platform usage ($10 entry)
 *     3. Blockchain transaction fees
 *
 * Payment Model (CORRECTED v2):
 *   - User pays $10 USD entry fee
 *   - $10 is recorded in Timestamp (append-only audit)
 *   - $10 is collected by Owner directly to personal bank account (NOT in smart contract)
 *   - Owner collects until system is fully operational
 *   - When system ready: $10 stops being collected (no more new fees)
 *   - Existing $10 payments → converted to BTM-TOKEN refund (value = $10 USD)
 *
 * Token Lifecycle:
 *   - PROOF_ONLY → created (no value yet)
 *   - 6-month proof-of-work window
 *   - ACTIVATED → when revenue streams validated
 *   - VALUED → when actual revenue realized + assessed
 *   - REFUNDABLE → when system ready, BTM-TOKEN = $10 issued to payer
 *   - After 6mo → EXPIRED (can renew for next cycle)
 *
 * Gas Cost: ~$0.05-0.20/day on Polygon (~$10/month)
 * ====================================================================
 */

interface IMerkleValidator {
    function verifyProof(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) external pure returns (bool);
}

contract DailyAnchor {
    // ====================================================================
    // Types & Enums
    // ====================================================================
    
    enum ChainType { Polygon, BNBChain, Ethereum }
    
    enum RevenueStreamType { 
        GPT_TRAINING,      // 0: AI discovery formula usage
        PLATFORM_USAGE,    // 1: AI-Success platform subscription
        TRANSACTION_FEE    // 2: Blockchain operation fees
    }
    
    enum TokenStatus {
        PROOF_ONLY,      // 0: Created, has sha256 + tstSignature, no value yet
        ACTIVATED,       // 1: Revenue stream validated, proof-of-work active
        VALUED,          // 2: Revenue realized, BTM-Token value assessed
        REFUNDABLE,      // 3: Ready to refund as BTM-TOKEN ($10 value)
        EXPIRED          // 4: 6-month window expired
    }
    
    struct DailyAnchorRecord {
        uint256 anchorDate;           // YYYYMMDD
        bytes32 merkleRoot;           // Root of all tokens created that day
        uint256 tokenCount;           // Number of tokens in batch
        ChainType chain;              // Which chain anchored
        bytes32 transactionHash;      // Blockchain tx hash
        uint256 blockNumber;          // Block number
        string proofRef;              // "LEO3C-BLOCKCHAIN-PROOF-20260927-001"
        uint256 timestamp;            // When anchored (UTC)
        bool isValid;                 // Validation flag
    }
    
    struct PaymentRecord {
        string tokenId;               // BTM-LEO3C-20260927-0001
        address paidBy;               // Original payer
        uint256 paidAmountUSDCents;   // $10 entry fee (in cents = 1000)
        uint256 paidAt;               // Timestamp when paid
        bool isRefundedAsToken;       // false → true after system ready
        uint256 refundedAt;           // null → timestamp when refunded
        string refundTokenId;         // BTM-TOKEN issued as refund
        string refundTxHash;          // Blockchain tx hash of refund (if on-chain)
    }
    
    struct RevenueStreamDaily {
        uint256 date;                 // YYYYMMDD
        RevenueStreamType streamType;
        uint256 tokenCountToday;      // How many tokens generated from this stream
        uint256 totalRevenueUSD;      // Revenue amount in USD (0 if not yet realized)
        uint256 btmTokenValue;        // Assessed BTM-Token value (0 if not yet assessed)
        uint256 lastUpdated;          // Timestamp of last update
        bool isRealized;              // true when actual revenue confirmed
    }
    
    struct TokenMetadata {
        string tokenId;               // BTM-LEO3C-20260927-0001
        bytes32 sha256;               // Original SHA256 hash
        string tstSignature;          // RFC3161 Timestamp signature
        uint256 createdAt;            // Creation timestamp
        uint256 expiresAt;            // createdAt + 6 months
        TokenStatus status;           // Current lifecycle status
        uint256 realValueUSD;         // Assessed USD value (0 initially)
        uint256 btmTokenValue;        // Assessed BTM-Token value (0 initially)
        RevenueStreamType revenueStream; // Which stream generated this token
        bool isValid;                 // Verification flag
        address owner;                // Token owner
    }
    
    // ====================================================================
    // State Variables
    // ====================================================================
    
    address public contractOwner;
    address public foundationAddress;
    address public systemCostAddress;
    
    bool public isSystemFullyOperational;  // Flag: when true, stop collecting $10 fees
    
    // Payment Configuration
    uint256 public constant PROOF_OF_WORK_DURATION = 6 * 30 days;  // 6 months in seconds
    uint256 public constant ENTRY_FEE_USD_CENTS = 1000;  // $10.00 in cents
    uint256 public constant REFUND_BTM_VALUE_USD_CENTS = 1000;  // Refund as $10 worth of BTM-TOKEN
    
    // Note: Entry fee is collected by owner OUTSIDE the contract
    // It's just recorded here for audit trail only
    
    // Daily anchors: date (YYYYMMDD) => DailyAnchorRecord
    mapping(uint256 => DailyAnchorRecord) public dailyAnchors;
    mapping(uint256 => bool) public dailyAnchorExists;
    
    // Token registry: tokenId => TokenMetadata
    mapping(string => TokenMetadata) public tokenRegistry;
    mapping(string => bool) public tokenExists;
    
    // Payment records: tokenId => PaymentRecord
    mapping(string => PaymentRecord) public paymentRecords;
    mapping(string => bool) public paymentExists;
    
    // Revenue streams: streamId => RevenueStreamDaily
    mapping(string => RevenueStreamDaily) public revenueStreams;
    uint256 public revenueStreamCount = 0;
    
    // Historical records
    uint256[] public allAnchorDates;
    string[] public allTokenIds;
    string[] public allPaymentTokenIds;
    
    // Stats
    uint256 public totalCollectedFeesUSDCents = 0;  // $10 * count
    uint256 public totalRefundedAsTokens = 0;       // Count of refunded tokens
    
    // ====================================================================
    // Events
    // ====================================================================
    
    event AnchorCreated(
        uint256 indexed date,
        bytes32 merkleRoot,
        uint256 tokenCount,
        string chain,
        bytes32 txHash,
        uint256 timestamp,
        string proofRef
    );
    
    event TokenRegistered(
        string indexed tokenId,
        bytes32 sha256,
        uint8 revenueStream,
        string status,
        address owner
    );
    
    event PaymentRecorded(
        string indexed tokenId,
        address indexed paidBy,
        uint256 amount,
        uint256 timestamp
    );
    
    event TokenStatusUpdated(
        string indexed tokenId,
        string oldStatus,
        string newStatus,
        uint256 timestamp
    );
    
    event TokenValuated(
        string indexed tokenId,
        uint256 realValueUSD,
        uint256 btmTokenValue,
        uint256 timestamp
    );
    
    event RefundIssuedAsToken(
        string indexed tokenId,
        address indexed paidBy,
        string refundTokenId,
        uint256 btmTokenValueUSD,
        string refundTxHash,
        uint256 timestamp
    );
    
    event RevenueStreamUpdated(
        uint256 indexed date,
        uint8 streamType,
        uint256 tokenCount,
        uint256 revenueUSD,
        bool isRealized
    );
    
    event SystemOperationalStatusChanged(
        bool isOperational,
        uint256 timestamp
    );
    
    // ====================================================================
    // Modifiers
    // ====================================================================
    
    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only owner can call this");
        _;
    }
    
    modifier validDate(uint256 dateYYYYMMDD) {
        require(dateYYYYMMDD >= 20260901 && dateYYYYMMDD <= 20991231, "Invalid date format");
        _;
    }
    
    modifier noDoubleAnchor(uint256 date) {
        require(!dailyAnchorExists[date], "Anchor already exists for this date");
        _;
    }
    
    modifier tokenMustExist(string memory _tokenId) {
        require(tokenExists[_tokenId], "Token not found in registry");
        _;
    }
    
    // ====================================================================
    // Constructor
    // ====================================================================
    
    constructor(
        address _foundationAddress,
        address _systemCostAddress
    ) {
        require(_foundationAddress != address(0), "Invalid foundation address");
        require(_systemCostAddress != address(0), "Invalid system cost address");
        
        contractOwner = msg.sender;
        foundationAddress = _foundationAddress;
        systemCostAddress = _systemCostAddress;
        isSystemFullyOperational = false;  // Initially NOT operational
    }
    
    // ====================================================================
    // Core: Daily Anchor (Proof Layer)
    // ====================================================================
    
    /**
     * @dev Create daily anchor (called at 00:00 UTC)
     * 
     * Flow:
     * 1. Batch all tokens created yesterday
     * 2. Compute Merkle root from sha256 + tstSignature
     * 3. Submit to public chain (Polygon/BNB)
     * 4. Record immutably (append-only)
     */
    function createDailyAnchor(
        uint256 _date,
        bytes32 _merkleRoot,
        uint256 _tokenCount,
        ChainType _chain,
        bytes32 _txHash,
        uint256 _blockNumber,
        string memory _proofRef
    ) 
        external 
        onlyOwner 
        validDate(_date) 
        noDoubleAnchor(_date)
    {
        DailyAnchorRecord memory record = DailyAnchorRecord({
            anchorDate: _date,
            merkleRoot: _merkleRoot,
            tokenCount: _tokenCount,
            chain: _chain,
            transactionHash: _txHash,
            blockNumber: _blockNumber,
            proofRef: _proofRef,
            timestamp: block.timestamp,
            isValid: true
        });
        
        dailyAnchors[_date] = record;
        dailyAnchorExists[_date] = true;
        allAnchorDates.push(_date);
        
        emit AnchorCreated(
            _date,
            _merkleRoot,
            _tokenCount,
            chainTypeToString(_chain),
            _txHash,
            block.timestamp,
            _proofRef
        );
    }
    
    /**
     * @dev Get daily anchor by date
     */
    function getDailyAnchor(uint256 _date) 
        external 
        view 
        returns (DailyAnchorRecord memory) 
    {
        require(dailyAnchorExists[_date], "No anchor for this date");
        return dailyAnchors[_date];
    }
    
    function getAnchorCount() 
        external 
        view 
        returns (uint256) 
    {
        return allAnchorDates.length;
    }
    
    // ====================================================================
    // Token Registration & Lifecycle
    // ====================================================================
    
    /**
     * @dev Register a new BTM token
     * 
     * Revenue streams:
     * 0 = GPT_TRAINING (AI discovery formula)
     * 1 = PLATFORM_USAGE (AI-Success platform subscription)
     * 2 = TRANSACTION_FEE (blockchain operation fees)
     * 
     * Initial status: PROOF_ONLY (no value yet)
     */
    function registerToken(
        string memory _tokenId,
        bytes32 _sha256,
        string memory _tstSignature,
        uint8 _revenueStreamType,
        address _tokenOwner
    ) 
        external 
        onlyOwner
    {
        require(!tokenExists[_tokenId], "Token already registered");
        require(_revenueStreamType <= 2, "Invalid revenue stream type");
        require(_tokenOwner != address(0), "Invalid token owner");
        
        uint256 createdAt = block.timestamp;
        uint256 expiresAt = createdAt + PROOF_OF_WORK_DURATION;
        
        TokenMetadata memory token = TokenMetadata({
            tokenId: _tokenId,
            sha256: _sha256,
            tstSignature: _tstSignature,
            createdAt: createdAt,
            expiresAt: expiresAt,
            status: TokenStatus.PROOF_ONLY,
            realValueUSD: 0,
            btmTokenValue: 0,
            revenueStream: RevenueStreamType(_revenueStreamType),
            isValid: true,
            owner: _tokenOwner
        });
        
        tokenRegistry[_tokenId] = token;
        tokenExists[_tokenId] = true;
        allTokenIds.push(_tokenId);
        
        emit TokenRegistered(
            _tokenId,
            _sha256,
            _revenueStreamType,
            "PROOF_ONLY",
            _tokenOwner
        );
    }
    
    /**
     * @dev Get token details
     */
    function getToken(string memory _tokenId) 
        external 
        view 
        tokenMustExist(_tokenId)
        returns (TokenMetadata memory) 
    {
        return tokenRegistry[_tokenId];
    }
    
    /**
     * @dev Update token status
     * Transition: PROOF_ONLY → ACTIVATED → VALUED → REFUNDABLE → EXPIRED
     */
    function updateTokenStatus(
        string memory _tokenId,
        TokenStatus _newStatus
    )
        external
        onlyOwner
        tokenMustExist(_tokenId)
    {
        TokenMetadata storage token = tokenRegistry[_tokenId];
        TokenStatus oldStatus = token.status;
        
        // Validate state transitions
        if (_newStatus == TokenStatus.ACTIVATED) {
            require(oldStatus == TokenStatus.PROOF_ONLY, "Can only activate PROOF_ONLY tokens");
        } else if (_newStatus == TokenStatus.VALUED) {
            require(
                oldStatus == TokenStatus.PROOF_ONLY || oldStatus == TokenStatus.ACTIVATED,
                "Can only value PROOF_ONLY or ACTIVATED tokens"
            );
        } else if (_newStatus == TokenStatus.REFUNDABLE) {
            require(isSystemFullyOperational, "System must be fully operational first");
            require(
                oldStatus == TokenStatus.PROOF_ONLY || 
                oldStatus == TokenStatus.ACTIVATED ||
                oldStatus == TokenStatus.VALUED,
                "Can only refund before expiry"
            );
        } else if (_newStatus == TokenStatus.EXPIRED) {
            require(block.timestamp > token.expiresAt, "Token not yet expired");
        }
        
        token.status = _newStatus;
        
        emit TokenStatusUpdated(
            _tokenId,
            statusToString(oldStatus),
            statusToString(_newStatus),
            block.timestamp
        );
    }
    
    /**
     * @dev Check if token is expired (6 months after creation)
     */
    function isTokenExpired(string memory _tokenId) 
        external 
        view 
        tokenMustExist(_tokenId)
        returns (bool) 
    {
        TokenMetadata memory token = tokenRegistry[_tokenId];
        return block.timestamp > token.expiresAt;
    }
    
    /**
     * @dev Get remaining proof-of-work time
     * @return remaining seconds until expiry
     */
    function getProofOfWorkRemaining(string memory _tokenId)
        external
        view
        tokenMustExist(_tokenId)
        returns (uint256)
    {
        TokenMetadata memory token = tokenRegistry[_tokenId];
        if (block.timestamp >= token.expiresAt) {
            return 0;
        }
        return token.expiresAt - block.timestamp;
    }
    
    // ====================================================================
    // Payment Recording (Audit Only — $10 collected outside contract)
    // ====================================================================
    
    /**
     * @dev Record $10 entry fee payment
     * 
     * Important: 
     * - $10 payment is recorded here ONLY for audit trail
     * - $10 is collected by Owner directly to personal bank account
     * - Not stored in smart contract
     * - Owner collects until isSystemFullyOperational = true
     * - Then: existing payments converted to BTM-TOKEN refund
     */
    function recordPayment(
        string memory _tokenId,
        address _paidBy,
        uint256 _amountUSDCents
    )
        external
        onlyOwner
        tokenMustExist(_tokenId)
    {
        require(!paymentExists[_tokenId], "Payment already recorded for this token");
        require(_paidBy != address(0), "Invalid payer address");
        require(_amountUSDCents == ENTRY_FEE_USD_CENTS, "Must be exactly $10");
        require(!isSystemFullyOperational, "Cannot record new payments - system operational");
        
        PaymentRecord memory payment = PaymentRecord({
            tokenId: _tokenId,
            paidBy: _paidBy,
            paidAmountUSDCents: _amountUSDCents,
            paidAt: block.timestamp,
            isRefundedAsToken: false,
            refundedAt: 0,
            refundTokenId: "",
            refundTxHash: ""
        });
        
        paymentRecords[_tokenId] = payment;
        paymentExists[_tokenId] = true;
        allPaymentTokenIds.push(_tokenId);
        totalCollectedFeesUSDCents += _amountUSDCents;
        
        emit PaymentRecorded(_tokenId, _paidBy, _amountUSDCents, block.timestamp);
    }
    
    /**
     * @dev Get payment record
     */
    function getPaymentRecord(string memory _tokenId)
        external
        view
        returns (PaymentRecord memory)
    {
        require(paymentExists[_tokenId], "No payment record for this token");
        return paymentRecords[_tokenId];
    }
    
    /**
     * @dev Get total collected fees (in USD cents)
     * Example: 10 * $10 = 100000 cents = $1000
     */
    function getTotalCollectedFees()
        external
        view
        returns (uint256)
    {
        return totalCollectedFeesUSDCents;
    }
    
    // ====================================================================
    // Token Valuation (Only when revenue is realized)
    // ====================================================================
    
    /**
     * @dev Valuate token when revenue streams are confirmed
     * 
     * Called when:
     * - GPT training revenue confirmed
     * - Platform subscription received
     * - Transaction fees realized
     * 
     * Then: Token moves toward REFUNDABLE status
     */
    function valuateToken(
        string memory _tokenId,
        uint256 _realValueUSD,
        uint256 _btmTokenValue
    )
        external
        onlyOwner
        tokenMustExist(_tokenId)
    {
        TokenMetadata storage token = tokenRegistry[_tokenId];
        require(
            token.status == TokenStatus.PROOF_ONLY || 
            token.status == TokenStatus.ACTIVATED,
            "Can only valuate PROOF_ONLY or ACTIVATED tokens"
        );
        
        token.realValueUSD = _realValueUSD;
        token.btmTokenValue = _btmTokenValue;
        token.status = TokenStatus.VALUED;
        
        emit TokenValuated(_tokenId, _realValueUSD, _btmTokenValue, block.timestamp);
    }
    
    // ====================================================================
    // Refund as BTM-TOKEN (When system is ready)
    // ====================================================================
    
    /**
     * @dev Issue BTM-TOKEN refund (value = $10)
     * 
     * Called after:
     * 1. System is fully operational (isSystemFullyOperational = true)
     * 2. Revenue streams calculated
     * 3. Ready to convert $10 payments to BTM-TOKEN
     * 
     * Refund = BTM-TOKEN (minted externally by BTMToken.sol)
     * Value = $10 USD equivalent
     * No cash refund
     */
    function issueRefundAsToken(
        string memory _tokenId,
        string memory _refundTokenId,
        string memory _refundTxHash
    )
        external
        onlyOwner
        tokenMustExist(_tokenId)
    {
        require(paymentExists[_tokenId], "No payment record for this token");
        require(isSystemFullyOperational, "System must be fully operational");
        
        PaymentRecord storage payment = paymentRecords[_tokenId];
        require(!payment.isRefundedAsToken, "Already refunded as token");
        
        TokenMetadata storage token = tokenRegistry[_tokenId];
        require(
            token.status == TokenStatus.PROOF_ONLY ||
            token.status == TokenStatus.ACTIVATED ||
            token.status == TokenStatus.VALUED,
            "Cannot refund expired tokens"
        );
        
        // Mark as refunded with BTM-TOKEN
        payment.isRefundedAsToken = true;
        payment.refundedAt = block.timestamp;
        payment.refundTokenId = _refundTokenId;
        payment.refundTxHash = _refundTxHash;
        
        // Update token status
        token.status = TokenStatus.REFUNDABLE;
        
        totalRefundedAsTokens++;
        
        emit RefundIssuedAsToken(
            _tokenId,
            payment.paidBy,
            _refundTokenId,
            REFUND_BTM_VALUE_USD_CENTS,
            _refundTxHash,
            block.timestamp
        );
    }
    
    // ====================================================================
    // System Status Management
    // ====================================================================
    
    /**
     * @dev Mark system as fully operational
     * 
     * After calling this:
     * - Cannot record new $10 payments
     * - Can start issuing BTM-TOKEN refunds
     * - Existing payments converted to BTM-TOKEN ($10 value each)
     */
    function markSystemAsOperational()
        external
        onlyOwner
    {
        require(!isSystemFullyOperational, "System already operational");
        isSystemFullyOperational = true;
        
        emit SystemOperationalStatusChanged(true, block.timestamp);
    }
    
    /**
     * @dev Get system operational status
     */
    function getSystemStatus()
        external
        view
        returns (bool isOperational, uint256 totalFeesCollected, uint256 totalRefunded)
    {
        return (isSystemFullyOperational, totalCollectedFeesUSDCents, totalRefundedAsTokens);
    }
    
    // ====================================================================
    // Revenue Streams Management
    // ====================================================================
    
    /**
     * @dev Create or update revenue stream
     * 
     * Streams:
     * 0 = GPT_TRAINING: AI discovery formula revenue
     * 1 = PLATFORM_USAGE: AI-Success platform subscription
     * 2 = TRANSACTION_FEE: Blockchain operation fees
     */
    function updateRevenueStream(
        uint256 _date,
        uint8 _streamType,
        uint256 _tokenCount,
        uint256 _revenueUSD,
        bool _isRealized
    )
        external
        onlyOwner
        validDate(_date)
    {
        require(_streamType <= 2, "Invalid stream type");
        
        string memory streamId = keccak256(abi.encodePacked(_date, _streamType));
        
        if (revenueStreams[streamId].date == 0) {
            revenueStreams[streamId] = RevenueStreamDaily({
                date: _date,
                streamType: RevenueStreamType(_streamType),
                tokenCountToday: _tokenCount,
                totalRevenueUSD: _revenueUSD,
                btmTokenValue: 0,
                lastUpdated: block.timestamp,
                isRealized: _isRealized
            });
            revenueStreamCount++;
        } else {
            revenueStreams[streamId].tokenCountToday = _tokenCount;
            revenueStreams[streamId].totalRevenueUSD = _revenueUSD;
            revenueStreams[streamId].isRealized = _isRealized;
            revenueStreams[streamId].lastUpdated = block.timestamp;
        }
        
        emit RevenueStreamUpdated(_date, _streamType, _tokenCount, _revenueUSD, _isRealized);
    }
    
    /**
     * @dev Get revenue stream
     */
    function getRevenueStream(uint256 _date, uint8 _streamType)
        external
        view
        returns (RevenueStreamDaily memory)
    {
        require(_streamType <= 2, "Invalid stream type");
        string memory streamId = keccak256(abi.encodePacked(_date, _streamType));
        return revenueStreams[streamId];
    }
    
    // ====================================================================
    // Utilities & Helpers
    // ====================================================================
    
    function chainTypeToString(ChainType _chain) 
        internal 
        pure 
        returns (string memory) 
    {
        if (_chain == ChainType.Polygon) return "Polygon";
        if (_chain == ChainType.BNBChain) return "BNB Chain";
        if (_chain == ChainType.Ethereum) return "Ethereum";
        return "Unknown";
    }
    
    function statusToString(TokenStatus _status)
        internal
        pure
        returns (string memory)
    {
        if (_status == TokenStatus.PROOF_ONLY) return "PROOF_ONLY";
        if (_status == TokenStatus.ACTIVATED) return "ACTIVATED";
        if (_status == TokenStatus.VALUED) return "VALUED";
        if (_status == TokenStatus.REFUNDABLE) return "REFUNDABLE";
        if (_status == TokenStatus.EXPIRED) return "EXPIRED";
        return "UNKNOWN";
    }
    
    function getTokenCount() 
        external 
        view 
        returns (uint256) 
    {
        return allTokenIds.length;
    }
    
    function getPaymentCount()
        external
        view
        returns (uint256)
    {
        return allPaymentTokenIds.length;
    }
    
    function getRevenueStreamCount()
        external
        view
        returns (uint256)
    {
        return revenueStreamCount;
    }
    
    // ====================================================================
    // Admin Functions
    // ====================================================================
    
    function transferOwnership(address _newOwner) 
        external 
        onlyOwner 
    {
        require(_newOwner != address(0), "Invalid new owner");
        contractOwner = _newOwner;
    }
    
    function updateFoundationAddress(address _newAddress) 
        external 
        onlyOwner 
    {
        require(_newAddress != address(0), "Invalid address");
        foundationAddress = _newAddress;
    }
    
    function updateSystemCostAddress(address _newAddress) 
        external 
        onlyOwner 
    {
        require(_newAddress != address(0), "Invalid address");
        systemCostAddress = _newAddress;
    }
}
